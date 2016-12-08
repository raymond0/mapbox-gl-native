//
//  urt_vector_tile.cpp
//  mbgl
//
//  Created by Ray Hunter on 29/11/2016.
//
//

#include <mbgl/tile/tile_loader_impl.hpp>
#include "urt_vector_tile.hpp"
#include <UrtFile/UrtFile.h>
#include <algorithm>
#include <iostream>
#include <string>
#include <unordered_map>
#include "rayclipper.h"

namespace mbgl
{
    
using namespace std;

class UrtVectorTileFeature : public GeometryTileFeature {
public:
    UrtVectorTileFeature( MapItem *mapItem, Region *region_, bool fromProxyTile_ );
    virtual unique_ptr<GeometryTileFeature> clone();
    
    virtual FeatureType getType() const override;
    optional<Value> getValue(const std::string&) const override;
    std::unordered_map<std::string,Value> getProperties() const override;
    optional<FeatureIdentifier> getID() const override;
    virtual GeometryCollection getGeometries() const override;
    
protected:
    Region *region;
    bool fromProxyTile;
    unordered_map<string,Value> properties;     // ToDo - switch to shared_ptr ???
    typedef std::pair<uint32_t, uint32_t> CoordRange;
    vector<CoordRange> RelevantCoordinateRangesInTileRect( MapItem *item ) const;
    GeometryCoordinates ConvertToMapboxCoordinates( const vector<coord> &globalCoords ) const;
    GeometryCoordinates GetMapboxCoordinatesInRange( MapItem *item, CoordRange coordRange ) const;
    GeometryCollection ClippedPolygonInLocalCoords( MapItem *item ) const;
private:
    MapItem *mapItem;
    unordered_map<string,Value> GetMapboxTags();
};
    
    
bool ItemTypeIsRoad( unsigned int type )
{
    bool isRoad = ( ( type_street_nopass <= type && type <= type_roundabout ) ||
                   type == type_living_street ||
                   type == type_street_parking_lane ||
                   type == type_street_service );
    
    return isRoad;
}


bool ItemTypeIsPlaceLabel( unsigned int type)
{
    return type_town_label <= type && type <= type_place_locality;
}
    
    
unordered_map<string,Value> UrtVectorTileFeature::GetMapboxTags()
{
    auto roadClassAndType = [=]() -> pair<string, string>
    {
        switch ( mapItem.itemType )
        {
            case type_street_nopass:        // ToDo - verify nopass
            case type_street_0:
                return pair<string, string>("street", "unclassified");
            case type_street_residential_city:
            case type_street_residential_land:
                return pair<string, string>("street", "residential");
            case type_street_tertiary_city:
            case type_street_tertiary_land:
                return pair<string, string>("tertiary", "tertiary");
            case type_ramp_tertiary:
                return pair<string, string>("link", "tertiary_link");
            case type_street_secondary_city:
            case type_street_secondary_land:
                return pair<string, string>("secondary", "secondary");
            case type_ramp_secondary:
                return pair<string, string>("link", "secondary_link");
            case type_street_primary_city:
            case type_street_primary_land:
                return pair<string, string>("primary", "primary");
            case type_ramp_primary:
                return pair<string, string>("link", "primary_link");
            case type_street_trunk:
            case type_roundabout:           // ToDo - Roundabout is trunk???
                return pair<string, string>("trunk", "trunk");
            case type_ramp_trunk:
                return pair<string, string>("link", "trunk_link");
            case type_highway_city:
            case type_street_motorway:
            case type_highway_land:
                return pair<string, string>("motorway", "motorway");
            case type_ramp_motorway:
                return pair<string, string>("motorway_link", "motorway_link");
            case type_living_street:
                return pair<string, string>("street", "living_street");
            case type_street_service:
                return pair<string, string>("service", "service");
            case type_street_parking_lane:
                return pair<string, string>("service", "service:parking_aisle");
                //
                //  Polygons
                //
            case type_poly_wood:
            case type_poly_park:
                return pair<string, string>("park", "garden");
                
                //
                //  Place labels
                //
            case type_place_city:
                return pair<string, string>("", "city");
            case type_place_suburb:
                return pair<string, string>("", "suburb");
            case type_place_quarter:
                return pair<string, string>("", "quarter");
            case type_place_neighbourhood:
                return pair<string, string>("", "neighbourhood");
            case type_place_town:
                return pair<string, string>("", "town");
            case type_place_village:
                return pair<string, string>("", "village");
            case type_place_hamlet:
                return pair<string, string>("", "hamlet");
            case type_place_island:
                return pair<string, string>("", "island");
            case type_place_islet:
                return pair<string, string>("", "islet");
            case type_place_locality:
                return pair<string, string>("", "locality");
            default:
                return pair<string, string>("", "");
        }
    }();
    
    unordered_map<string,Value> mapboxTags;
    
    if ( roadClassAndType.first.length() > 0 )
    {
        mapboxTags.insert({"class", (string) roadClassAndType.first});
    }
    
    if ( roadClassAndType.second.length() > 0 )
    {
        mapboxTags.insert({"type", (string) roadClassAndType.second});
    }
    
    if ( ItemTypeIsRoad(mapItem.itemType) )
    {
        mapboxTags.insert({"oneway", (string) "false"});   // ToDo
        mapboxTags.insert({"structure", (string) "none"}); // ToDo
    }
    
    if ( ItemTypeIsPlaceLabel(mapItem.itemType) )
    {
        NSString *townLabelStr = [[mapItem attributeOfType: attr_town_name] stringForAttribute];
        const char *townLabel = townLabelStr.UTF8String;
        
        if ( townLabel != NULL )
        {
            mapboxTags.insert({"name", (string) townLabel});
            mapboxTags.insert({"name_en", (string) townLabel});
        }
        
        //mapboxTags.emplace_back("ldir", (string) "N");
        //mapboxTags.emplace_back("localrank", (uint64_t) 1);
        //mapboxTags.emplace_back("scalerank", (uint64_t) 1);
        
    }
    
    return mapboxTags;
}
    
    
UrtVectorTileFeature::UrtVectorTileFeature(MapItem *mapItem_, Region *region_, bool fromProxyTile_)
{
    mapItem = mapItem_;
    properties = GetMapboxTags();
    region = region_;
    fromProxyTile = fromProxyTile_;
}
    
    
unique_ptr<GeometryTileFeature> UrtVectorTileFeature::clone()
{
    auto other = make_unique<UrtVectorTileFeature>(mapItem, region, fromProxyTile);
    other->properties = properties;
    return move(other);
}
    
    
FeatureType UrtVectorTileFeature::getType() const
{
    if ( ItemTypeIsPlaceLabel( mapItem.itemType ) )
    {
        return FeatureType::Point;
    }
    else if (  mapItem.itemType >= type_area )
    {
        return FeatureType::Polygon;
    }
    else
    {
        return FeatureType::LineString;
    }
}


optional<Value> UrtVectorTileFeature::getValue(const std::string& key) const {
    auto result = properties.find(key);
    if (result == properties.end()) {
        return optional<Value>();
    }
    
    return result->second;
}
    

std::unordered_map<std::string,Value> UrtVectorTileFeature::getProperties() const
{
    return properties;
}
    

optional<FeatureIdentifier> UrtVectorTileFeature::getID() const
{
    return optional<FeatureIdentifier>();
}
    
    
vector<UrtVectorTileFeature::CoordRange> UrtVectorTileFeature::RelevantCoordinateRangesInTileRect( MapItem *item ) const
{
    vector<CoordRange> validRanges;
    coord *coords;
    NSInteger nrCoords = [item lengthOfCoordinatesWithData:&coords];
    
    if ( nrCoords == 1 )
    {
        if ( [region containsCoord:coords[0]] )
        {
            validRanges.emplace_back(CoordRange(0,1));
        }
        return validRanges;
    }
    
    bool currentlyValid = false;
    NSInteger segmentStart = 0;
    NSInteger segmentEnd = 0;
    
    for ( NSInteger i = 1; i < nrCoords; i++ )
    {
        if (  [region containsOrIntersetsFrom:coords[i-1] to:coords[i]] )
        {
            if ( currentlyValid )
            {
                segmentEnd = i;
            }
            else
            {
                segmentStart = i - 1;
                segmentEnd = i;
                currentlyValid = true;
            }
        }
        else
        {
            if ( currentlyValid )
            {
                validRanges.emplace_back(CoordRange(segmentStart, segmentEnd - segmentStart + 1));
                
                currentlyValid = false;
            }
        }
    }
    
    if ( currentlyValid )
    {
        validRanges.emplace_back(CoordRange(segmentStart, segmentEnd - segmentStart + 1));
        
        currentlyValid = false;
    }
    
    return validRanges;
}
    
    
GeometryCoordinates UrtVectorTileFeature::ConvertToMapboxCoordinates( const vector<coord> &globalCoords ) const
{
    Coordinate *origin = region.minimum;
    static const double extent = util::EXTENT;
    const double latExtent = region.height;
    const double lonExtent = region.width;
    
    const double latMultiplier = extent / latExtent;
    const double lonMultiplier = extent / lonExtent;
    
    GeometryCoordinates output;
    
    for ( const auto &coord : globalCoords )
    {
        struct coord localCoord = [origin localCoordinateFrom:coord];
        
        double tileX = ((double) localCoord.x ) * lonMultiplier;
        double tileY = ((double) localCoord.y ) * latMultiplier;
        
        GeometryCoordinate outputCoord( tileX, extent - tileY );
        
        if ( output.size() > 0 )
        {
            if ( output.back().x == outputCoord.x &&  output.back().y == outputCoord.y )
            {
                continue;
            }
        }
        
        output.emplace_back( outputCoord );
    }
    
    return output;
}
    
    
GeometryCoordinates UrtVectorTileFeature::GetMapboxCoordinatesInRange( MapItem *item, CoordRange coordRange ) const
{
    Coordinate *origin = region.minimum;
    static const double extent = util::EXTENT;
    const double latExtent = region.height;
    const double lonExtent = region.width;
    
    const double latMultiplier = extent / latExtent;
    const double lonMultiplier = extent / lonExtent;
    
    coord *coords;
    __unused unsigned int nrCoords = (unsigned int) [item lengthOfCoordinatesWithData:&coords];
    
    GeometryCoordinates output;
    
    for ( uint32_t i = 0; i < coordRange.second; i++ )
    {
        assert( coordRange.first + i < nrCoords );
        coord localCoord = [origin localCoordinateFrom:coords[ coordRange.first + i ]];

        double tileX = ((double) localCoord.x ) * lonMultiplier;
        double tileY = ((double) localCoord.y ) * latMultiplier;
        
        GeometryCoordinate outputCoord( tileX, extent - tileY );
        
        if ( i > 0 )
        {
            if ( output.back().x == outputCoord.x &&  output.back().y == outputCoord.y )
            {
                continue;
            }
        }
        
        output.emplace_back( outputCoord );
    }
    
    return output;
}
    
    
GeometryCollection UrtVectorTileFeature::ClippedPolygonInLocalCoords( MapItem *item ) const
{
    GeometryCollection lines;
    coord *coords = nil;
    NSInteger nrCoords = [item lengthOfCoordinatesWithData:&coords];
    
    rayclipper::Polygon inputPolygon;
    inputPolygon.resize( nrCoords );
    
    for ( NSInteger i = 0; i < nrCoords; i++ )
    {
        inputPolygon[i] = coords[i];
    }
    
    rayclipper::rect rect = {region.minimum.coord, region.maximum.coord};
    auto outPolygons = RayClipPolygon( inputPolygon, rect );
    
    for ( auto &outPolygon : outPolygons )
    {
        auto localPolygon = ConvertToMapboxCoordinates( outPolygon );
        if ( localPolygon.size() >= 3 )
        {
            lines.emplace_back( localPolygon );
        }
    }
    
    return lines;
}


GeometryCollection UrtVectorTileFeature::getGeometries() const
{
    //
    // ToDo - this will handle roads. Polygon's need to be clipped and have first coordinate appended at end
    //
    if ( ItemTypeIsRoad( mapItem.itemType ) )
    {
        auto coordinateRanges = RelevantCoordinateRangesInTileRect( mapItem );
        
        GeometryCollection lines;
        for ( auto range : coordinateRanges )
        {
            auto coords = GetMapboxCoordinatesInRange( mapItem, range );
            lines.emplace_back( coords );
        }
        
        return lines;
    }
    
    if ( fromProxyTile )
    {
        return ClippedPolygonInLocalCoords(mapItem);
    }

    GeometryCollection lines;
    NSInteger nrCoords = [mapItem lengthOfCoordinatesWithData:nil];
    auto allUnclippedCoords = GetMapboxCoordinatesInRange( mapItem, CoordRange( 0, nrCoords ) );
    lines.emplace_back( allUnclippedCoords );
    return lines;
}
    
    
class UrtVectorTileWaterFeature : public UrtVectorTileFeature
{
public:
    UrtVectorTileWaterFeature( Region *region_ );
    virtual unique_ptr<GeometryTileFeature> clone() override;
    void addLandArea( MapItem *landArea, bool fromProxyTile );
    
    FeatureType getType() const override;
    GeometryCollection getGeometries() const override;
    
private:
    vector<pair<MapItem *, bool> > landAreas;
};

    
UrtVectorTileWaterFeature::UrtVectorTileWaterFeature( Region *region_ )
    : mbgl::UrtVectorTileFeature( NULL, region_, false )
{
    
}
    
    
unique_ptr<GeometryTileFeature> UrtVectorTileWaterFeature::clone()
{
    auto other = make_unique<UrtVectorTileWaterFeature>( region );
    other->landAreas = landAreas;
    return move(other);
}

    
void UrtVectorTileWaterFeature::addLandArea( MapItem *landArea, bool fromProxyTile )
{
    landAreas.emplace_back( landArea, fromProxyTile );
}
    
    
FeatureType UrtVectorTileWaterFeature::getType() const
{
    return FeatureType::Polygon;
}
    
    
bool PolygonMatchesExtent( const GeometryCoordinates &polygon )
{
    if ( polygon.size() != 4 )
    {
        return false;
    }
    
    size_t origin = SIZE_MAX;
    
    for ( size_t i = 0; i < 4; i++ )
    {
        if ( polygon[i].x == 0 && polygon[i].y == 0 )
        {
            origin = i;
            break;
        }
    }
    
    if ( origin == SIZE_MAX )
    {
        return false;
    }
    
    if ( polygon[(origin + 1) % 4].x != util::EXTENT || polygon[(origin + 1) % 4].y != 0 ||
         polygon[(origin + 2) % 4].x != util::EXTENT || polygon[(origin + 2) % 4].y != util::EXTENT ||
         polygon[(origin + 3) % 4].x != 0 || polygon[(origin + 3) % 4].y != util::EXTENT )
    {
        return false;
    }
    
    return true;
}
    
    
/*long long GeomArea(GeometryCoordinates c)
{
    long long area=0;
    size_t i,j=0;
    for ( i=0 ; i < c.size(); i++ )
    {
        if (++j == c.size())
            j=0;
        area+=(long long)(c[i].x+c[j].x)*(c[i].y-c[j].y);
    }
    return area/2;
}*/
    
    
GeometryCollection UrtVectorTileWaterFeature::getGeometries() const
{
    GeometryCollection lines;

    //
    //  Add a border of 1 all around the edge. Tangent edges on valid polygons *sometimes* blow
    //  something up further down the line without this, and invalidate all land areas.
    //  Docs do state we need to avoid tanget edges.
    //
    GeometryCoordinates line;
    line.emplace_back( GeometryCoordinate(0 - 1,0 - 1) );
    line.emplace_back( GeometryCoordinate(0 - 1,util::EXTENT + 1) );
    line.emplace_back( GeometryCoordinate(util::EXTENT + 1, util::EXTENT + 1) );
    line.emplace_back( GeometryCoordinate(util::EXTENT + 1, 0 - 1) );
    
    lines.emplace_back( line );
    if ( landAreas.size() == 0 )
        return lines;
    
    for ( auto &landArea : landAreas )
    {
        if ( landArea.second )      // Is proxy tile
        {
            GeometryCollection clippedPolyResults = ClippedPolygonInLocalCoords(landArea.first);
            for ( auto &poly : clippedPolyResults )
            {
                assert( poly.size() >= 3 );
                
                if ( poly.size() == 4 )
                {
                    if ( PolygonMatchesExtent( poly ) )
                    {
                        GeometryCollection emptyLines;
                        return emptyLines;
                    }
                }
                
                if ( poly.front() != poly.back() )
                {
                    poly.emplace_back(poly.front());
                }
            }
            
            if ( clippedPolyResults.size() > 0 )
            {
                lines.insert( lines.end(), clippedPolyResults.begin(), clippedPolyResults.end() );
            }
        }
        else
        {
            NSInteger nrCoords = [landArea.first lengthOfCoordinatesWithData:nil];
            GeometryCoordinates landCoords = GetMapboxCoordinatesInRange( landArea.first, CoordRange( 0, nrCoords ) );
            lines.emplace_back( landCoords );
        }
    }
    
#ifdef DUMP_POLYGON_INFO
    printf("========== Land Polygons start ==========\n");
    
    for ( auto &polygon : lines )
    {
        printf("---------- Land Polygon start ---------- Area: %lld\n", GeomArea(polygon));
        for ( auto &coord : polygon )
        {
            printf( "Coord: %d, %d\n", coord.x, coord.y );
        }
    }
#endif
    
    
#ifdef DUMP_POLYGON_INTERSECTIONS
    for ( size_t i = lines.size() - 1; i > 0; i-- )
    {
        auto &firstPolygonCoords = lines[i];
        vector<coord> firstPolygon;
        
        for ( auto c : firstPolygonCoords )
        {
            struct coord coord = { c.x, c.y };
            firstPolygon.emplace_back(coord);
        }
        
        for ( size_t j = i -1; j > 1; j-- )
        {
            auto &secondPolygon = lines[j];

            for ( auto &testCoord : secondPolygon )
            {
                struct coord coord = { testCoord.x, testCoord.y };
                if ( rayclipper::PointIsInsidePolygon(firstPolygon, coord) )
                {
                    printf( "Intersection Coord: %d, %d\n", coord.x, coord.y );
                    //lines.erase( lines.begin() + j );
                    //j--;
                    //break;
                }
            }
        }
    }
#endif
    
    return lines;
}


class UrtTileLayer : public GeometryTileLayer {
public:
    UrtTileLayer( string name_, Region *region_ ) { name = name_; region = region_; }
    virtual void addMapItem( MapItem *mapItem, bool fromProxyTile );
    virtual void finalizeInternalItems() {}     // No more items to add
    
    virtual std::size_t featureCount() const override { return features.size(); }
    virtual std::unique_ptr<GeometryTileFeature> getFeature(std::size_t) const override;
    virtual std::string getName() const override;
    
protected:
    Region *region;
    string name;
    vector<unique_ptr<UrtVectorTileFeature> > features;
};
    
    
void UrtTileLayer::addMapItem( MapItem *mapItem, bool fromProxyTile )
{
    auto feature = make_unique<UrtVectorTileFeature>(mapItem, region, fromProxyTile);
    features.emplace_back( move(feature) );
}
    
    
unique_ptr<GeometryTileFeature> UrtTileLayer::getFeature(std::size_t i) const
{
    return features.at(i)->clone();
}
    
    
string UrtTileLayer::getName() const
{
    return name;
}
    

class WaterTileLayer : public UrtTileLayer
{
public:
    WaterTileLayer( string name_, Region *region_ ) : UrtTileLayer( name_, region_) { groundType = type_none; }
    virtual void addMapItem( MapItem *mapItem, bool fromProxyTile );
    virtual void finalizeInternalItems();
    
    void setWholeGroundType( item_type groundType );
private:
    vector<pair<MapItem *, bool> > landFeatures;
    vector<pair<MapItem *, bool> > waterFeatures;
    item_type groundType;
};
    
    
void WaterTileLayer::addMapItem( MapItem *mapItem, bool fromProxyTile )
{
    if ( mapItem.itemType == type_poly_water )
    {
        waterFeatures.emplace_back( mapItem, fromProxyTile );
    }
    else if ( mapItem.itemType == type_poly_land )
    {
        landFeatures.emplace_back( mapItem, fromProxyTile );
    }
    else
    {
        assert( false && "Can only handle water and land types" );
    }
}

    
void WaterTileLayer::finalizeInternalItems()
{
    //
    //  Ground is anything that's not water
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
    
    //
    //  Whole area is water
    //
    auto feature = make_unique<UrtVectorTileWaterFeature>(region);
    
    for ( auto &landItem : landFeatures )
    {
        feature->addLandArea( landItem.first, landItem.second );
    }
    
    features.emplace_back( move(feature) );
}


void WaterTileLayer::setWholeGroundType( item_type groundType_ )
{
    //assert ( wholeTileGroundType == type_none );
    groundType = groundType_;
}


typedef enum
{
    LayerPolyWood = 0,
    LayerPolyWater,
    LayerRoad,
    LayerOther,
    LayerPlaceLabel,
    LayerCount
} LayerType;
    
const string LAYER_UNDEFINED = "UNDEFINED";
vector<string> layerNames = { "landuse", "water", "road", LAYER_UNDEFINED, "place_label"  };


LayerType LayerForItemType( unsigned int itemType )
{
    switch (itemType)
    {
        case type_poly_land:
        case type_poly_water:
            return LayerPolyWater;
        case type_poly_wood:
        case type_poly_park:
            return LayerPolyWood;
        default:
            if ( ItemTypeIsPlaceLabel ( itemType ) )
            {
                return LayerPlaceLabel;
            }
            else if ( ItemTypeIsRoad( itemType ) )
            {
                return LayerRoad;
            }
            else
            {
                return LayerOther;
            }
            break;
    }
}


UrtVectorTile::UrtVectorTile(const OverscaledTileID& id_,
                             std::string sourceID_,
                             const style::UpdateParameters& parameters,
                             const Tileset& tileset)
    : GeometryTile(id_, sourceID_, parameters),
    loader(*this, id_, parameters, tileset)
{
    
}

    
void UrtVectorTile::setNecessity(Necessity necessity) {
    if ( necessity == Resource::Required )
    {
        loader.setNecessity(necessity);
    }   
}
    
    
class UrtVectorTileData : public GeometryTileData {
public:
    UrtVectorTileData(std::shared_ptr<UrtTileData> data);
    
    std::unique_ptr<GeometryTileData> clone() const override {
        return std::make_unique<UrtVectorTileData>(*this);
    }
    
    const GeometryTileLayer* getLayer(const std::string&) const override;
    
private:
    std::shared_ptr<UrtTileData> data;
    mutable bool parsed = false;

    typedef std::vector<std::shared_ptr<UrtTileLayer> > LayersType;
    std::shared_ptr< LayersType > layers;
    void parse() const;
    void addMapTile( MapTile *mapTile, bool wasProxyTile, NSInteger tileLevel ) const;
    bool shouldIncludeItemType( unsigned int itemType, NSInteger tileLevel ) const;
    item_type wholeTileGroundType;
};
    
    
UrtVectorTileData::UrtVectorTileData(std::shared_ptr<UrtTileData> data_)
: data(std::move(data_))
{
    NSString *tilename = ( __bridge NSString * ) data->tilenameNSString();
    Region *region = [[Region alloc] initForTileName:tilename];
    
    layers = shared_ptr< LayersType >( new LayersType() );
    for ( auto layerName : layerNames )
    {
        if ( layerName == "water" )
        {
            layers->emplace_back(shared_ptr<UrtTileLayer> (new WaterTileLayer(layerName, region)));
        }
        else
        {
            layers->emplace_back(shared_ptr<UrtTileLayer> (new UrtTileLayer(layerName, region)));
        }
    }
}

    
const GeometryTileLayer* UrtVectorTileData::getLayer(const std::string& name) const
{
    if (!parsed && data != nullptr )
    {
        parsed = true;
        
        assert( data != nullptr );
        //NSString *tilename = ( __bridge NSString * ) data->tilenameNSString();
        //printf( "Parsing tile %s\n", tilename.UTF8String );
        
        parse();
        
        //printf( "Finished parsing tile %s\n", tilename.UTF8String );
    }
    
    auto layerPosition = std::find( layerNames.begin(), layerNames.end(), name );
    if ( layerPosition == layerNames.end() )
    {
        return nullptr;
    }
    
    auto index = layerPosition - layerNames.begin();
    assert ( index < LayerCount );
    return layers->at(index).get();
}
    
    
bool UrtVectorTileData::shouldIncludeItemType( unsigned int itemType, NSInteger tileLevel ) const
{
    if ( ! ItemTypeIsRoad( itemType ) )
        return true;
    
    switch ( itemType )
    {
        case type_living_street:
        case type_street_parking_lane:
        case type_street_pedestrian:
        case type_street_service:
            return tileLevel >= 15;
            
        case type_street_nopass:
        case type_street_0:
        case type_street_residential_city:
        case type_street_residential_land:
            return tileLevel >= 13;
            
        case type_street_tertiary_city:
        case type_street_tertiary_land:
        case type_ramp_tertiary:
            return tileLevel >= 11;

        case type_street_secondary_city:
        case type_street_secondary_land:
        case type_ramp_secondary:
            return tileLevel >= 9;

        case type_street_primary_city:
        case type_street_primary_land:
        case type_ramp_primary:
            return tileLevel >= 7;
            
        case type_highway_city:
        case type_street_motorway:  // Trunk link
        case type_highway_land:
        case type_ramp_motorway:
        case type_street_trunk:
        case type_ramp_trunk:
        case type_roundabout:
            return tileLevel >= 6;
            
        default:
            assert( false && "Unhandled road type" );
    }

    return true;
}

    
void UrtVectorTileData::addMapTile( MapTile *mapTile, bool fromProxyTile, NSInteger tileLevel ) const
{
    NSEnumerator *mapItemEnumerator = [mapTile mapItemEnumerator];
    MapItem *mapItem;
    
    while ( (mapItem = [mapItemEnumerator nextObject]) != nil )
    {
        BOOL wasParentRef = NO;
        unsigned int itemType = mapItem.itemType;
        
        if ( type_parent_ref_1 <= itemType && itemType <= type_parent_ref_20 )
        {
            mapItem = [mapTile resolveUpreferenceForItem:mapItem];
            if ( mapItem == nil )
            {
                continue;
            }
            wasParentRef = YES;
            itemType = mapItem.itemType;
        }
        
        if ( ! shouldIncludeItemType( mapItem.itemType, tileLevel ) )
        {
            continue;
        }
        
        LayerType layer = LayerForItemType( itemType );
        layers->at(layer)->addMapItem( mapItem, fromProxyTile );
    }
    
    item_type tileCover = [mapTile completeGroundType];
    if ( tileCover != type_none )
    {
        auto waterLayer = dynamic_cast<WaterTileLayer *>(layers->at(LayerPolyWater).get());
        assert( waterLayer != nullptr );
        waterLayer->setWholeGroundType(tileCover);
    }
}


void UrtVectorTileData::parse() const
{
    NSArray<MapTile *> *mapTiles = ( __bridge NSArray * ) data->maptilesPtr();
    NSString *tilename = ( __bridge NSString * ) data->tilenameNSString();
    NSInteger tileLevel = tilename.length;
    
    for ( MapTile *mapTile in mapTiles )
    {
        if ( mapTile.isPlanetOceanMapTile && mapTiles.count > 1 && tileLevel >= 8 )     // ToDo - remove
            continue;
        
        bool blankNode = false;
        MapTile *tile = mapTile;
        
        while ( tile.blankNode && tile != nil )
        {
            blankNode = true;
            tile = tile.parent;
        }
        
        addMapTile( tile, blankNode, tileLevel );
    }
    
    layers->at(LayerPolyWater)->finalizeInternalItems();
}
    

void UrtVectorTile::setData(std::shared_ptr<const std::string>,
                         optional<Timestamp> modified_,
                         optional<Timestamp> expires_,
                         std::shared_ptr<UrtTileData> urtTile_)
{
    modified = modified_;
    expires = expires_;
    
    assert( urtTile_ != nullptr );
    
    auto dataItem = urtTile_ != nullptr ? std::make_unique<UrtVectorTileData>(urtTile_) : nullptr;
    
    GeometryTile::setData(std::move(dataItem));
}
    
}
