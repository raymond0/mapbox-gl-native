//
//  urt_water_tile_layer.hpp
//  mbgl
//
//  Created by Ray Hunter on 09/12/2016.
//
//

#pragma once

#import "urt_tile_layer.hpp"
#import <vector>

namespace mbgl {
   
using namespace std;

class WaterTileLayer : public UrtTileLayer
{
public:
    WaterTileLayer( string name_, Region *region_ ) : UrtTileLayer( name_, region_) { groundType = type_none; }
    virtual void addMapItem( MapItem *mapItem, bool fromProxyTile );
    virtual void finalizeInternalItems();
    
    void setWholeGroundType( item_type groundType );
private:
    vector<pair<MapItem *, bool> > landFeatures;
    vector<pair<MapItem *, bool> > waterFeatures;
    item_type groundType;
};

    
}
