//
//  urt_vector_tile_water_feature.hpp
//  mbgl
//
//  Created by Ray Hunter on 09/12/2016.
//
//

#pragma once

#import "urt_vector_tile_feature.hpp"

namespace mbgl {

using namespace std;
    
class UrtVectorTileWaterFeature : public UrtVectorTileFeature
{
public:
    UrtVectorTileWaterFeature( URRegion region_ );
    virtual void addMapItem( MapItem *mapItem ) override;
    virtual unique_ptr<GeometryTileFeature> clone() override;
    
    void addLandArea( MapItem *landArea, bool fromProxyTile );
    
    FeatureType getType() const override;
    GeometryCollection getGeometries() const override;
};

}
