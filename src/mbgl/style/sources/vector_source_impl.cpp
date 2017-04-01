#include <mbgl/style/sources/vector_source_impl.hpp>
#include <mbgl/tile/vector_tile.hpp>
#include <mbgl/urt/urt_vector_tile.hpp>
#include <mbgl/urt/urt_file_source.hpp>
#include <mbgl/style/update_parameters.hpp>
#include <mbgl/storage/default_file_source.hpp>

namespace mbgl {
namespace style {

VectorSource::Impl::Impl(std::string id_, Source& base_, variant<std::string, Tileset> urlOrTileset_)
    : TileSourceImpl(SourceType::Vector, std::move(id_), base_, std::move(urlOrTileset_), util::tileSize) {
}

std::unique_ptr<Tile> VectorSource::Impl::createTile(const OverscaledTileID& tileID,
                                                     const UpdateParameters& parameters) {
    return std::make_unique<AutoVectorTile>(tileID, base.getID(), parameters, tileset);
}

} // namespace style
} // namespace mbgl
