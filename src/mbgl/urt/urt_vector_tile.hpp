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
#include <mbgl/urt/urt_tile_data.hpp>
#include <mbgl/tile/geometry_tile_data.hpp>
#include <mbgl/tile/vector_tile.hpp>

namespace mbgl {

class UrtVectorTile : virtual public GeometryTile
{
public:
    UrtVectorTile(const OverscaledTileID& id_,
                  std::string sourceID_,
                  const style::UpdateParameters& parameters,
                  const Tileset& tileset);

    virtual void setNecessity(Necessity);
    virtual void setData(std::shared_ptr<const std::string> data,
                 optional<Timestamp> modified,
                 optional<Timestamp> expires,
                 std::shared_ptr<UrtTileData> urtFile);
    
private:
    TileLoader<UrtVectorTile> loader;
};
    
    
class AutoVectorTile : virtual public VectorTile, virtual public UrtVectorTile
{
public:
    AutoVectorTile(const OverscaledTileID& id_,
                   std::string sourceID_,
                   const style::UpdateParameters& parameters,
                   const Tileset& tileset) :
    GeometryTile(id_, sourceID_, parameters),
    VectorTile( id_, sourceID_, parameters, tileset),
    UrtVectorTile( id_, sourceID_, parameters, tileset )
    {
        
    }
    
    void setNecessity(Necessity necessity) final
    {
        VectorTile::setNecessity(necessity);
        UrtVectorTile::setNecessity(necessity);
    }
    void setData(std::shared_ptr<const std::string> data,
                 optional<Timestamp> modified,
                 optional<Timestamp> expires,
                 std::shared_ptr<UrtTileData> urtFile)
    {
        if ( urtFile != nullptr )
        {
            UrtVectorTile::setData(data, modified, expires, urtFile);
        }
        else
        {
            VectorTile::setData(data, modified, expires, urtFile);
        }
    }
    
};

}
