//
//  urt_vector_tile_feature.hpp
//  mbgl
//
//  Created by Ray Hunter on 09/12/2016.
//
//

#pragma once


#include <vector>
#include <mbgl/tile/geometry_tile_data.hpp>
#include <UrtFile/UrtFile.h>
#include <memory>
#include "urt_region.hpp"

namespace mbgl
{
    using namespace std;
    
    class UrtVectorTileFeature : public GeometryTileFeature {
    public:
        UrtVectorTileFeature( unsigned int itemType_, URRegion region_, bool fromProxyTile_ );
        virtual void addMapItem( MapItem *mapItem );
        virtual ~UrtVectorTileFeature();
        virtual unique_ptr<GeometryTileFeature> clone();
        
        virtual FeatureType getType() const override;
        optional<Value> getValue(const std::string&) const override;
        std::unordered_map<std::string,Value> getProperties() const override;
        optional<FeatureIdentifier> getID() const override;
        virtual GeometryCollection getGeometries() const override;
        
    protected:
        virtual GeometryCollection getGeometriesForMapItem(MapItem *mapItem) const;
        typedef unordered_map<string,Value> MapboxTags;
        typedef shared_ptr<MapboxTags> MapboxTagsPtr;
        virtual MapboxTagsPtr GetMapboxTags() const;    // To override in subclasses
        
        typedef struct CoordRange
        {
            typedef enum
            {
                Empty,
                Internal,       // All (except maybe first and last points) are relevant
                Intersection    // No points inside, but 2 points intersect
            } RangeType;

            NSInteger index;
            NSInteger length;
            RangeType rangeType;
            
            CoordRange( NSInteger _index, NSInteger _length, RangeType _rangeType )
            {
                index = _index;
                length = _length;
                rangeType = _rangeType;
            }
        } CoordRange;

        URRegion region;
        bool fromProxyTile;
        MapboxTagsPtr properties;
        GeometryCollection geometryCollection;
        vector<CoordRange> RelevantCoordinateRangesInTileRect( MapItem *item ) const;
        GeometryCoordinates ConvertToMapboxCoordinates( const vector<coord> &globalCoords ) const;
        GeometryCoordinates GetMapboxCoordinatesInRange( MapItem *item, CoordRange coordRange ) const;
        GeometryCollection ClippedPolygonInLocalCoords( MapItem *item ) const;
        unsigned int itemType;
    private:
    };

}