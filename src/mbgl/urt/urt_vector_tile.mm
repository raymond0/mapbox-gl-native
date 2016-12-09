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
#include "urt_water_tile_layer.hpp"

namespace mbgl
{
    
using namespace std;
    
    
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


typedef enum
{
    LayerPolyWood = 0,
    LayerPolyWater,
    LayerRoad,
    LayerRoadLabel,
    LayerPlaceLabel,
    LayerCount
} LayerType;


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
                return LayerCount;
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
    
    layers->emplace_back(shared_ptr<UrtTileLayer> (new UrtTileLayer("landuse", region)));
    layers->emplace_back(shared_ptr<UrtTileLayer> (new WaterTileLayer("water", region)));
    layers->emplace_back(shared_ptr<UrtTileLayer> (new UrtRoadTileLayer("road", region)));
    layers->emplace_back(shared_ptr<UrtTileLayer> (new UrtTileLayer("road_label", region)));
    layers->emplace_back(shared_ptr<UrtTileLayer> (new UrtPlaceTileLayer("place_label", region)));
    
    assert( layers->size() == LayerCount );
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
    
    for ( auto &layer : *layers )
    {
        if ( layer->getName() == name )
        {
            return layer.get();
        }
    }

    return nullptr;
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
        
        if ( layer == LayerCount )
        {
            continue;
        }
        
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
