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
        UrtVectorTilePlaceLabelFeature( unsigned int itemType_, URRegion region_, bool fromProxyTile_ );
        virtual void addMapItem( MapItem *mapItem ) override;
        virtual unique_ptr<GeometryTileFeature> clone() override;
        
        virtual FeatureType getType() const override;
    protected:
        virtual MapboxTagsPtr GetMapboxTags() const override;
    private:
        std::string townLabelString;
        int population;
    };

    
    class UrtVectorTileCountryLabelFeature : public UrtVectorTileFeature
    {
    public:
        UrtVectorTileCountryLabelFeature( unsigned int itemType_, URRegion region_, bool fromProxyTile_ );
        virtual void addMapItem( MapItem *mapItem ) override;
        virtual unique_ptr<GeometryTileFeature> clone() override;
        
        virtual FeatureType getType() const override;
    protected:
        virtual MapboxTagsPtr GetMapboxTags() const override;
    private:
        std::string labelString;
        int population;
    };

}
