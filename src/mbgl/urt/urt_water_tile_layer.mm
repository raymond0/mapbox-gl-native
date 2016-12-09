//
//  urt_water_tile_layer.cpp
//  mbgl
//
//  Created by Ray Hunter on 09/12/2016.
//
//

#include "urt_water_tile_layer.hpp"
#import "urt_vector_tile_water_feature.hpp"

namespace mbgl {
    
void WaterTileLayer::addMapItem( MapItem *mapItem, bool fromProxyTile )
{
    if ( mapItem.itemType == type_poly_water )
    {
        waterFeatures.emplace_back( mapItem, fromProxyTile );
    }
    else if ( mapItem.itemType == type_poly_land )
    {
        landFeatures.emplace_back( mapItem, fromProxyTile );
    }
    else
    {
        assert( false && "Can only handle water and land types" );
    }
}


void WaterTileLayer::finalizeInternalItems()
{
    //
    //  Ground is anything that's not water (thus "nothing" is water, as is water)
    //
    if ( groundType != type_none && groundType != type_whole_area_type_water )
    {
        for ( auto waterItem : waterFeatures )
        {
            UrtTileLayer::addMapItem( waterItem.first, waterItem.second );
        }
        
        // ToDo - Handle land coverage feature
        return;
    }
    
    //
    //  Whole area is water
    //
    auto feature = make_unique<UrtVectorTileWaterFeature>(region);
    
    for ( auto &landItem : landFeatures )
    {
        feature->addLandArea( landItem.first, landItem.second );
    }
    
    feature->addWaterAreas( waterFeatures.begin(), waterFeatures.end() );
    
    features.emplace_back( move(feature) );
}


void WaterTileLayer::setWholeGroundType( item_type groundType_ )
{
    //assert ( wholeTileGroundType == type_none );
    groundType = groundType_;
}

}
