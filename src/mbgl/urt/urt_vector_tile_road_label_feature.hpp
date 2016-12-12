//
//  urt_vector_tile_road_label_feature.hpp
//  mbgl
//
//  Created by Ray Hunter on 12/12/2016.
//
//

#pragma once

#import "urt_vector_tile_feature.hpp"

namespace mbgl
{
    using namespace std;
    
    class UrtVectorTileRoadLabelFeature : public UrtVectorTileFeature
    {
    public:
        UrtVectorTileRoadLabelFeature( MapItem *mapItem, Region *region_, bool fromProxyTile_ );
        virtual unique_ptr<GeometryTileFeature> clone() override;
        
        virtual FeatureType getType() const override;
        virtual GeometryCollection getGeometries() const override;
        
        bool shouldRender();
    protected:
        virtual MapboxTagsPtr GetMapboxTags() const override;

        UrtVectorTileFeature::CoordRange longestSection() const;
        double distanceOfSection(UrtVectorTileFeature::CoordRange &section) const;
        double distanceOfLongestSection() const;
    };
}
