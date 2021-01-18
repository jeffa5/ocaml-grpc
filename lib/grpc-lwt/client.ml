open Lwt.Syntax

type response_handler = H2.Client_connection.response_handler

type do_request =
  ?trailers_handler:(H2.Headers.t -> unit) ->
  H2.Request.t ->
  response_handler:response_handler ->
  [ `write ] H2.Body.t

let make_request ~scheme ~service ~rpc =
  let request =
    H2.Request.create ~scheme `POST
      ("/" ^ service ^ "/" ^ rpc)
      ~headers:
        H2.Headers.(
          add_list empty
            [ ("te", "trailers"); ("content-type", "application/grpc+proto") ])
  in
  request

let call ~service ~rpc ?(scheme = "https") ~handler ~do_request () =
  let request = make_request ~service ~rpc ~scheme in
  let read_body, read_body_notify = Lwt.wait () in
  let handler_res, handler_res_notify = Lwt.wait () in
  let out, out_notify = Lwt.wait () in
  let response_handler (response : H2.Response.t) body =
    Lwt.wakeup_later read_body_notify body;
    Lwt.async (fun () ->
        if response.status <> `OK then (
          Lwt.wakeup_later out_notify
            (Error (Grpc.Status.v Grpc.Status.Unknown));
          Lwt.return_unit )
        else
          let+ handler_res = handler_res in
          Lwt.wakeup_later out_notify (Ok handler_res))
  in
  let status, status_notify = Lwt.wait () in
  let trailers_handler headers =
    let code =
      match H2.Headers.get headers "grpc-status" with
      | None -> None
      | Some s -> (
          match int_of_string_opt s with
          | None -> None
          | Some i -> Grpc.Status.code_of_int i )
    in
    match code with
    | None -> ()
    | Some code ->
        let message = H2.Headers.get headers "grpc-message" in
        let status = Grpc.Status.v ?message code in
        Lwt.wakeup_later status_notify status
  in
  let write_body =
    do_request ?trailers_handler:(Some trailers_handler) request
      ~response_handler
  in
  Lwt.async (fun () ->
      let+ handler_res = handler write_body read_body in
      Lwt.wakeup_later handler_res_notify handler_res);
  let* out = out in
  let+ status = status in
  match out with Error _ as e -> e | Ok out -> Ok (out, status)

module Rpc = struct
  type 'a handler =
    [ `write ] H2.Body.t -> [ `read ] H2.Body.t Lwt.t -> 'a Lwt.t

  let bidirectional_streaming ~f write_body read_body =
    let decoder_stream, decoder_push = Lwt_stream.create () in
    Lwt.async (fun () ->
        let+ read_body = read_body in
        Connection.grpc_recv_streaming read_body decoder_push);
    let encoder_stream, encoder_push = Lwt_stream.create () in
    Lwt.async (fun () ->
        Connection.grpc_send_streaming_client write_body encoder_stream);
    let+ out = f (fun encoder -> encoder_push (Some encoder)) decoder_stream in
    encoder_push None;
    out

  let client_streaming ~f =
    bidirectional_streaming ~f:(fun encoder_push decoder_stream ->
        let decoder = Lwt_stream.get decoder_stream in
        f encoder_push decoder)

  let server_streaming ~f enc =
    bidirectional_streaming ~f:(fun encoder_push decoder_stream ->
        encoder_push enc;
        f decoder_stream)

  let unary ~f enc =
    bidirectional_streaming ~f:(fun encoder_push decoder_stream ->
        encoder_push enc;
        let decoder = Lwt_stream.get decoder_stream in
        f decoder)
end
