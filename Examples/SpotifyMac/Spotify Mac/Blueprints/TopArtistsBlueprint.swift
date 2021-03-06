import Spots
import Sugar
import Brick
import Tailor

struct TopArtistsBlueprint: BlueprintContainer {

  static let key = "top-artists"
  static var drawing: Blueprint {
    return Blueprint(
      cacheKey: "top-artists",
      requests: [(
        request: nil,
        rootKey: "artists",
        spotIndex: 0,
        adapter: { json in
          var viewModels = [Item]()
          for item in json {

            var description = ""
            let followers: Int = item.resolve(keyPath: "followers.total") ?? 0
            if followers > 0 {
              description += "Followers: \(followers)\n"
            }

            if let genres = item["genres"] as? [String] , !genres.isEmpty {
              description += "Genres: \(genres.joined(separator: ","))\n"
            }

            if let popularity: Int = item.resolve(keyPath: "popularity") {
              description += "Popularity: \(popularity)\n"
            }

            viewModels.append(Item(
              title : item.resolve(keyPath: "name") ?? "",
              image : item.resolve(keyPath: "images.2.url") ?? "",
              kind: "artist",
              action: "artist:\(item.resolve(keyPath: "id") ?? "")",
              size: CGSize(width: 180, height: 180),
              meta: ["fragments" : [
                "title" : item.resolve(keyPath: "name") ?? "",
                "image" : item.resolve(keyPath: "images.1.url") ?? "",
                "description" : description
                ]]
              ))
          }

          viewModels.sort { $0.title < $1.title }

          return viewModels
      })],
      template: [
        "components" : [
          [
            "title" : "Top Artists",
            "kind" : Component.Kind.Grid.rawValue,
            "items" : [
              "title" : "Loading..."
            ]
          ]
        ]
      ]
    )
  }
}
