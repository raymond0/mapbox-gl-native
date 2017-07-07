#pragma once

#include <mbgl/tile/geometry_tile.hpp>
#include <mbgl/tile/tile_loader.hpp>

namespace mbgl {

class Tileset;
class TileParameters;

class VectorTile : virtual public GeometryTile {
public:
    VectorTile(const OverscaledTileID&,
               std::string sourceID,
               const TileParameters&,
               const Tileset&);

    virtual void setNecessity(Necessity);
    virtual void setData(std::shared_ptr<const std::string> data,
                 optional<Timestamp> modified,
                 optional<Timestamp> expires,
                 std::shared_ptr<UrtTileData> urtFile);

private:
    TileLoader<VectorTile> loader;
};

} // namespace mbgl
