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
    UrtVectorTileRoadFeature( unsigned int itemType_, URRegion region_, bool fromProxyTile_ );
    virtual void addMapItem( MapItem *mapItem ) override;
    virtual unique_ptr<GeometryTileFeature> clone() override;
    
    virtual FeatureType getType() const override;

protected:
    MapboxTagsPtr GetMapboxTags() const override;
    static MapboxTagsPtr GetMapboxTagsStatic(unsigned int itemType, BOOL isOneway);
    static MapboxTagsPtr CreateMapboxTags(unsigned int itemType, BOOL isOneWay);
    virtual GeometryCollection getGeometriesForMapItem( MapItem *mapItem ) const override;
    GeometryCollection geometries;
    bool isOneway;
private:
};


}
