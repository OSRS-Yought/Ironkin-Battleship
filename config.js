// ---------------------------------------------------------------------
//  Supabase connection + site identity.
//
//  The publishable key is meant to be public. It is safe in a GitHub repo.
//  Row-level security (schema.sql / security.sql) is what protects the data.
//  Never put the service_role / secret key here.
// ---------------------------------------------------------------------

window.BB_CONFIG = {
  supabaseUrl: "https://pzxeauhieamxnoanlkjm.supabase.co",
  supabaseAnonKey: "sb_publishable_BeJLYnRf6MIlu2b8_CDcPA_2SdbOEU6",

  // Header, sign-in screen, and both exported PNGs.
  title: "Ironkin Battleship Bingo",
  subtitle: "Forged alone, bound as kin",

  // Your team. Shown beside the wordmark and stamped on exports.
  team: "Apey's Apes",

  // What happens when someone signs in who is NOT on the crew roster.
  //   false          -> polite "Not aboard" screen (recommended while you
  //                     are still adding people to the roster)
  //   true           -> redirect them to the video
  //   "https://..."  -> redirect them wherever you like
  rickroll: true,
};
