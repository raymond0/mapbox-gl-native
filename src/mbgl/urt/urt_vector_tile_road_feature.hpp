//
//  urt_vector_tile_road_feature.hpp
//  mbgl
//
//  Created by Ray Hunter on 09/12/2016.
//
//

#pragma once

#import "urt_vector_tile_feature.hpp"

namespace mbgl
{

using namespace std;
    
class UrtVectorTileRoadFeature : public UrtVectorTileFeature
{
public:
    UrtVectorTileRoadFeature( MapItem *mapItem, Region *region_, bool fromProxyTile_ );
    virtual unique_ptr<GeometryTileFeature> clone() override;
    
    virtual FeatureType getType() const override;
    virtual GeometryCollection getGeometries() const override;

protected:
    MapboxTagsPtr GetMapboxTags() const override;
};


}
