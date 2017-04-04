//
//  urt_vector_tile_whole_area_feature.hpp
//  
//
//  Created by Ray Hunter on 04/04/2017.
//
//

#pragma once

#import "urt_vector_tile_feature.hpp"

namespace mbgl {
    
    using namespace std;
    
    class UrtVectorTileWholeAreaFeature : public UrtVectorTileFeature
    {
    public:
        UrtVectorTileWholeAreaFeature( Region *region_, item_type _itemType );
        virtual unique_ptr<GeometryTileFeature> clone() override;

        virtual FeatureType getType() const override;
        virtual GeometryCollection getGeometries() const override;
        
    protected:
        UrtVectorTileFeature::MapboxTagsPtr GetMapboxTags() const override;
        item_type itemType;
    };
    
}
