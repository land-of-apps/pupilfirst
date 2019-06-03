type t = {
  userId: string,
  name: string,
  avatarUrl: string,
};

let userId = t => t.userId;

let name = t => t.name;

let avatarUrl = t => t.avatarUrl;

let decode = json =>
  Json.Decode.{
    userId: json |> field("userId", string),
    name: json |> field("name", string),
    avatarUrl: json |> field("avatarUrl", string),
  };