(* (c) 2017, 2018 Hannes Mehnert, all rights reserved *)

open Lwt.Infix

open Mirage_types_lwt

module Main (R : RANDOM) (P : PCLOCK) (M : MCLOCK) (T : TIME) (S : STACKV4) = struct
  module D = Udns_mirage_resolver.Make(R)(P)(M)(T)(S)

  let start _r pclock mclock _ s _ =
    let trie =
      List.fold_left
        (fun trie (k, v) -> Udns_trie.insertb k v trie)
        Udns_trie.empty Udns_resolver_root.reserved_zones
    in
    (match Udns_trie.check trie with
     | Ok () -> ()
     | Error e ->
       Logs.err (fun m -> m "check after update returned %a" Udns_trie.pp_zone_check e)) ;
    let now = M.elapsed_ns mclock in
    let server =
      Udns_server.Primary.create ~a:[Udns_server.Authentication.tsig_auth]
        ~tsig_verify:Udns_tsig.verify ~tsig_sign:Udns_tsig.sign ~rng:R.generate
        trie
    in
    let p = Udns_resolver.create now R.generate server in
    D.resolver ~timer:1000 ~root:true s p ;
    S.listen s
end
