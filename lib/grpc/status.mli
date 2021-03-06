type code =
  | OK
  | Cancelled
  | Unknown
  | Invalid_argument
  | Deadline_exceeded
  | Not_found
  | Already_exists
  | Permission_denied
  | Resource_exhausted
  | Failed_precondition
  | Aborted
  | Out_of_range
  | Unimplemented
  | Internal
  | Unavailable
  | Data_loss
  | Unauthenticated

(** [code] represents the valid gRPC status codes to respond with. *)

val int_of_code : code -> int
(** [int_of_code c] returns the corresponding integer status code for [c]. *)

type t
(** [t] represents a full gRPC status, this includes code and optional message. *)

val v : ?message:string -> code -> t
(** [v ~message code] creates a new status with the given [code] and [message]. *)

val code : t -> code
(** [code t] returns the code associated with [t]. *)

val message : t -> string option
(** [message t] returns the message associated with [t], if there is one. *)
