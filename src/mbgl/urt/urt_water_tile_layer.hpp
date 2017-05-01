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
    WaterTileLayer( string name_, URRegion region_ ) : UrtTileLayer( name_, region_) { groundType = type_none; }
    
    void setWholeGroundType( item_type groundType );
private:
};

    
}
