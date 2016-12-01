//
//  urt_vector_tile.hpp
//  mbgl
//
//  Created by Ray Hunter on 29/11/2016.
//
//

#pragma once

#include <stdio.h>
#include <memory>
#include <mbgl/tile/urt_tile_data.hpp>
#include <mbgl/tile/geometry_tile_data.hpp>
#include <mbgl/tile/vector_tile.hpp>

namespace mbgl {

class UrtTileLayer;

class UrtVectorTile : public GeometryTile
{
public:
    UrtVectorTile(const OverscaledTileID& id_,
                  std::string sourceID_,
                  const style::UpdateParameters& parameters,
                  const Tileset& tileset);

    void setNecessity(Necessity) final;
    void setData(std::shared_ptr<const std::string> data,
                 optional<Timestamp> modified,
                 optional<Timestamp> expires,
                 std::shared_ptr<UrtTileData> urtFile);
    
private:
    TileLoader<UrtVectorTile> loader;
};

}
