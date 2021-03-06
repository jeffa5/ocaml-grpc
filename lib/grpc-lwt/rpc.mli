type unary = Pbrt.Decoder.t -> (Grpc.Status.t * Pbrt.Encoder.t option) Lwt.t
(** [unary] is the type for a unary grpc rpc, one request, one response. *)

type client_streaming =
  Pbrt.Decoder.t Lwt_stream.t -> (Grpc.Status.t * Pbrt.Encoder.t option) Lwt.t
(** [client_streaming] is the type for an rpc where the client streams the requests and the server responds once. *)

type server_streaming =
  Pbrt.Decoder.t -> (Pbrt.Encoder.t -> unit) -> Grpc.Status.t Lwt.t
(** [server_streaming] is the type for an rpc where the client sends one request and the server sends multiple responses. *)

type bidirectional_streaming =
  Pbrt.Decoder.t Lwt_stream.t -> (Pbrt.Encoder.t -> unit) -> Grpc.Status.t Lwt.t
(** [bidirectional_streaming] is the type for an rpc where both the client and server can send multiple messages. *)

type t =
  | Unary of unary
  | Client_streaming of client_streaming
  | Server_streaming of server_streaming
  | Bidirectional_streaming of bidirectional_streaming

(** [t] represents the types of rpcs available in gRPC. *)

val unary : f:unary -> H2.Reqd.t -> unit Lwt.t
(** [unary ~f reqd] calls [f] with the request obtained from [reqd] and handles sending the response. *)

val client_streaming : f:client_streaming -> H2.Reqd.t -> unit Lwt.t
(** [client_streaming ~f reqd] calls [f] with a stream to pull requests from and handles sending the response. *)

val server_streaming : f:server_streaming -> H2.Reqd.t -> unit Lwt.t
(** [server_streaming ~f reqd] calls [f] with the request optained from [reqd] and handles sending the responses pushed out. *)

val bidirectional_streaming :
  f:bidirectional_streaming -> H2.Reqd.t -> unit Lwt.t
(** [bidirectional_streaming ~f reqd] calls [f] with a stream to pull requests from and andles sending the responses pushed out. *)
