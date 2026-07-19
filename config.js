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
  subtitle: "Blackout — finish the board",

  // Team tag. Empty string = no tag anywhere.
  team: "",

  // Blackout mode: the event is over and the survivors are clearing the
  // whole board. Splash disappears, HIT becomes DONE, tallies read
  // Done / Left. Existing hit/splash data is preserved untouched.
  blackout: true,

  // What happens when someone signs in who is NOT on the crew roster.
  rickroll: false,

  // Dead now that the event site is retired.
  boardSourceUrl: "",
};
