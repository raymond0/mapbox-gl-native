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

namespace mbgl
{
    
using namespace std;

class UrtVectorTileFeature : public GeometryTileFeature {
public:
    UrtVectorTileFeature( MapItem *mapItem, Region *region_, bool fromProxyTile_ );
    
    FeatureType getType() const override;
    optional<Value> getValue(const std::string&) const override;
    std::unordered_map<std::string,Value> getProperties() const override;
    optional<FeatureIdentifier> getID() const override;
    GeometryCollection getGeometries() const override;
    
private:
    Region *region;
    MapItem *mapItem;
    bool fromProxyTile;
    unordered_map<string,Value> GetMapboxTags();
    unordered_map<string,Value> properties;
    typedef std::pair<uint32_t, uint32_t> CoordRange;
    vector<CoordRange> RelevantCoordinateRangesInTileRect() const;
    GeometryCoordinates GetMapboxCoordinatesInRange( CoordRange coordRange ) const;
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
    
    
vector<UrtVectorTileFeature::CoordRange> UrtVectorTileFeature::RelevantCoordinateRangesInTileRect() const
{
    vector<CoordRange> validRanges;
    coord *coords;
    NSInteger nrCoords = [mapItem lengthOfCoordinatesWithData:&coords];
    
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
    
    
GeometryCoordinates UrtVectorTileFeature::GetMapboxCoordinatesInRange( CoordRange coordRange ) const
{
    Coordinate *origin = region.minimum;
    static const double extent = util::EXTENT;
    const double latExtent = region.height;
    const double lonExtent = region.width;
    
    const double latMultiplier = extent / latExtent;
    const double lonMultiplier = extent / lonExtent;
    
    coord *coords;
    unsigned int nrCoords = (unsigned int) [mapItem lengthOfCoordinatesWithData:&coords];
    
    GeometryCoordinates output;
    
    for ( uint32_t i = 0; i < coordRange.second; i++ )
    {
        assert( coordRange.first + i < nrCoords );
        coord localCoord = [origin localCoordinateFrom:coords[ coordRange.first + i ]];

        double tileX = ((double) localCoord.lon ) * lonMultiplier;
        double tileY = ((double) localCoord.lat ) * latMultiplier;
        
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


GeometryCollection UrtVectorTileFeature::getGeometries() const
{
    //
    // ToDo - this will handle roads. Polygon's need to be clipped and have first coordinate appended at end
    //
    if ( ItemTypeIsRoad( mapItem.itemType ) )
    {
        auto coordinateRanges = RelevantCoordinateRangesInTileRect();
        
        GeometryCollection lines;
        for ( auto range : coordinateRanges )
        {
            auto coords = GetMapboxCoordinatesInRange( range );
            lines.emplace_back( coords );
        }
        
        return lines;
    }
    
    GeometryCollection lines;
    
    if ( fromProxyTile )
    {
        return lines;
    }

    NSInteger nrCoords = [mapItem lengthOfCoordinatesWithData:nil];
    auto coords = GetMapboxCoordinatesInRange( CoordRange( 0, nrCoords ) );
    lines.emplace_back( coords );
    return lines;
}


class UrtTileLayer : public GeometryTileLayer {
public:
    UrtTileLayer( string name_, Region *region_ ) { name = name_; region = region_; }
    void addMapItem( MapItem *mapItem, bool formProxyTile );
    
    std::size_t featureCount() const override { return features.size(); }
    std::unique_ptr<GeometryTileFeature> getFeature(std::size_t) const override;
    std::string getName() const override;
    
private:
    Region *region;
    string name;
    vector<pair<MapItem *, bool> > features;
};
    
    
void UrtTileLayer::addMapItem( MapItem *mapItem, bool fromProxyTile )
{
    features.emplace_back( mapItem, fromProxyTile );
}

    
    
unique_ptr<GeometryTileFeature> UrtTileLayer::getFeature(std::size_t i) const
{
    return std::make_unique<UrtVectorTileFeature>(features.at(i).first, region, features.at(i).second);
}
    
    
string UrtTileLayer::getName() const
{
    return name;
}


typedef enum
{
    LayerPolyLand = 0,
    LayerPolyWood,
    LayerPolyWater,
    LayerRoad,
    LayerLine,
    LayerPlaceLabel,
    LayerCount
} LayerType;
    
const string LAYER_UNDEFINED = "UNDEFINED";
vector<string> layerNames = { LAYER_UNDEFINED, "landuse", "water", "road", LAYER_UNDEFINED, "place_label"  };


LayerType LayerForItemType( unsigned int itemType )
{
    switch (itemType)
    {
        case type_poly_water:
            return LayerPolyWater;
        case type_poly_wood:
        case type_poly_park:
            return LayerPolyWood;
        case type_poly_land:
            return LayerPolyLand;
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
                return LayerLine;
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
    loader.setNecessity(necessity);
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
    void addMapTile( MapTile *mapTile, bool wasProxyTile ) const;
};
    
    
UrtVectorTileData::UrtVectorTileData(std::shared_ptr<UrtTileData> data_)
: data(std::move(data_))
{
    NSString *tilename = ( __bridge NSString * ) data->tilenameNSString();
    Region *region = [[Region alloc] initForTileName:tilename];
    
    layers = shared_ptr< LayersType >( new LayersType() );
    for ( auto layerName : layerNames )
    {
        layers->emplace_back(shared_ptr<UrtTileLayer> (new UrtTileLayer(layerName, region)));
    }
}

    
const GeometryTileLayer* UrtVectorTileData::getLayer(const std::string& name) const
{
    if (!parsed && data != nullptr )
    {
        parsed = true;
        
        assert( data != nullptr );
        NSString *tilename = ( __bridge NSString * ) data->tilenameNSString();
        printf( "Parsing tile %s\n", tilename.UTF8String );
        
        parse();
        
        printf( "Finished parsing tile %s\n", tilename.UTF8String );
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

    
void UrtVectorTileData::addMapTile( MapTile *mapTile, bool fromProxyTile ) const
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
        
        LayerType layer = LayerForItemType( itemType );
        layers->at(layer)->addMapItem( mapItem, fromProxyTile );
    }

}


void UrtVectorTileData::parse() const
{
    NSArray<MapTile *> *mapTiles = ( __bridge NSArray * ) data->maptilesPtr();

    for ( MapTile *mapTile in mapTiles )
    {
        bool blankNode = false;
        MapTile *tile = mapTile;
        
        while ( tile.blankNode && tile != nil )
        {
            blankNode = true;
            tile = tile.parent;
        }
        
        addMapTile( tile, blankNode );
    }
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
