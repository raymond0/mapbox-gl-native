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
        UrtVectorTileRoadLabelFeature( unsigned int itemType_, URRegion region_, bool fromProxyTile_ );
        virtual void addMapItem( MapItem *mapItem ) override;
        virtual unique_ptr<GeometryTileFeature> clone() override;
        
        virtual FeatureType getType() const override;
        
        bool shouldRender( MapItem *mapItem );
    protected:
        virtual MapboxTagsPtr GetMapboxTags() const override;
        virtual GeometryCollection getGeometriesForMapItem( MapItem *mapItem ) const override;

        UrtVectorTileFeature::CoordRange longestSection(MapItem *mapItem) const;
        double distanceOfSection(MapItem *mapItem, UrtVectorTileFeature::CoordRange &section) const;
        double distanceOfLongestSection(MapItem *mapItem) const;
        std::string roadLabelString;
        double longestSectionDistance;
    };
}
