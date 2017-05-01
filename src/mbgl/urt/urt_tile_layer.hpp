//
//  urt_tile_layer.hpp
//  mbgl
//
//  Created by Ray Hunter on 09/12/2016.
//
//

#pragma once

#include <mbgl/tile/geometry_tile_data.hpp>
#include <string>
#include <UrtFile/UrtFile.h>
#include "urt_vector_tile_feature.hpp"
#include "urt_region.hpp"

namespace mbgl {
    
using namespace std;

class UrtTileLayer : public GeometryTileLayer
{
public:
    UrtTileLayer( string name_, URRegion region_ ) { name = name_; region = region_; }
    virtual ~UrtTileLayer() = default;
    virtual void addMapItem( MapItem *mapItem, bool fromProxyTile );
    virtual void finalizeInternalItems();     // No more items to add
    
    virtual std::size_t featureCount() const override { return features.size(); }
    virtual std::unique_ptr<GeometryTileFeature> getFeature(std::size_t) const override;
    virtual std::string getName() const override;
    
    void setWholeGroundType( item_type groundType );
protected:
    URRegion region;
    string name;
    vector<unique_ptr<UrtVectorTileFeature> > features;
    item_type groundType;
};
    
    
class UrtRoadLabelTileLayer : public UrtTileLayer
{
public:
    UrtRoadLabelTileLayer( string name_, URRegion region_ ) : UrtTileLayer ( name_, region_ ) {}
    virtual void addMapItem( MapItem *mapItem, bool fromProxyTile );
};

    
class UrtRoadTileLayer : public UrtTileLayer
{
public:
    UrtRoadTileLayer( string name_, URRegion region_ ) : UrtTileLayer ( name_, region_ ) {}
    virtual void addMapItem( MapItem *mapItem, bool fromProxyTile );
};


class UrtPlaceTileLayer : public UrtTileLayer
{
public:
    UrtPlaceTileLayer( string name_, URRegion region_ ) : UrtTileLayer ( name_, region_ ) {}
    virtual void addMapItem( MapItem *mapItem, bool fromProxyTile );
};
    
    
}
