//
//  urt_vector_tile_place_label_feature.hpp
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
    
    class UrtVectorTilePlaceLabelFeature : public UrtVectorTileFeature
    {
    public:
        UrtVectorTilePlaceLabelFeature( MapItem *mapItem, Region *region_, bool fromProxyTile_ );
        virtual unique_ptr<GeometryTileFeature> clone() override;
        
        virtual FeatureType getType() const override;
    protected:
        virtual MapboxTagsPtr GetMapboxTags() const override;
    };
}
