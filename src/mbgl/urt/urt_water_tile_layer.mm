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
    if ( mapItem.itemType == type_poly_water || mapItem.itemType == type_poly_ocean )
    {
        waterFeatures.emplace_back( mapItem, fromProxyTile );
    }
    else if ( mapItem.itemType == type_poly_inner_hole )
    {
        assert( waterFeatures.size() > 0 && "Can have a land hole without first having some water" );
        assert( waterFeatures.back().first.itemType == type_poly_ocean || waterFeatures.back().first.itemType == type_poly_water && "trying to add a water hole to something thats not ocean" );
        assert( waterFeatures.back().second == fromProxyTile && "Both water item and its hole should have proxy status matching" );
        [waterFeatures.back().first addPolygonHole:mapItem];
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
    //  Whole area is water. Create a special feature that handles this and treats land as holes.
    //
    auto feature = make_unique<UrtVectorTileWaterFeature>(region);
    
    for ( auto &landItem : landFeatures )
    {
        feature->addLandArea( landItem.first, landItem.second );
    }
    
    feature->addWaterAreas( waterFeatures.begin(), waterFeatures.end() );
    
    features.emplace_back( move(feature) );
}


}
