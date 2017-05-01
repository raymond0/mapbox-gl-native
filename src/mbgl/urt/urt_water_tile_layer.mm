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

/*void WaterTileLayer::finalizeInternalItems()
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
    
    //assert( false );
    
    //
    //  Whole area is water. Create a special feature that handles this and treats land as holes.
    //
    auto feature = make_unique<UrtVectorTileWaterFeature>(region);
    features.emplace_back( move(feature) );
    
    for ( auto &landItem : landFeatures )
    {
        feature->addLandArea( landItem.first, landItem.second );
    }
    
    feature->addWaterAreas( waterFeatures.begin(), waterFeatures.end() );
    
}*/


}
