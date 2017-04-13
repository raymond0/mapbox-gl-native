//
//  urt_file_source.cpp
//  mbgl
//
//  Created by Ray Hunter on 16/11/2016.
//
//

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wunused-function"
#pragma GCC diagnostic ignored "-Wunused-parameter"
#pragma GCC diagnostic ignored "-Wunused-variable"
#pragma GCC diagnostic ignored "-Wshadow"
#pragma GCC diagnostic ignored "-Wunknown-pragmas"
#pragma GCC diagnostic ignored "-Wpragmas"
#pragma GCC diagnostic ignored "-Wdeprecated-register"
#pragma GCC diagnostic ignored "-Wshorten-64-to-32"
#pragma GCC diagnostic ignored "-Wunused-local-typedefs"
#pragma GCC diagnostic ignored "-Wmaybe-uninitialized"
#include <fstream>
#include <iostream>
#include <string>
#include <sstream>
#include <boost/iostreams/stream.hpp>
#include <boost/iostreams/stream_buffer.hpp>
#include <boost/iostreams/filtering_streambuf.hpp>
#include <boost/iostreams/copy.hpp>
#include <boost/iostreams/filter/gzip.hpp>
#pragma GCC diagnostic pop

#include <mbgl/urt/urt_file_source.hpp>
#include <mbgl/util/async_task.hpp>
#import "UrtFile/UrtFile.h"
#include <mutex>

namespace mbgl {
    
    
// Data that is shared between the requesting thread and the thread running the completion handler.
class URTRequestShared {
public:
    URTRequestShared(Response& response_, util::AsyncTask& async_)
    : response(response_),
    async(async_) {
    }
    
    void notify(const Response& response_) {
        std::lock_guard<std::mutex> lock(mutex);
        if (!cancelled) {
            response = response_;
            async.send();
        }
    }
    
    void cancel() {
        std::lock_guard<std::mutex> lock(mutex);
        cancelled = true;
    }
    
private:
    std::mutex mutex;
    bool cancelled = false;
    
    Response& response;
    util::AsyncTask& async;
};

class URTRequest : public AsyncRequest {
public:
    URTRequest(FileSource::Callback callback_)
    : shared(std::make_shared<URTRequestShared>(response, async)),
    callback(callback_) {
    }
    
    ~URTRequest() override {
        shared->cancel();
    }
    
    std::shared_ptr<URTRequestShared> shared;
    
private:
    FileSource::Callback callback;
    Response response;
    
    util::AsyncTask async { [this] {
        // Calling `callback` may result in deleting `this`. Copy data to temporaries first.
        auto callback_ = callback;
        auto response_ = response;
        callback_(response_);
    } };
};
    
    
class URTFileSource::Impl
{
public:
    Impl();
    std::unique_ptr<AsyncRequest> request(const Resource&, Callback);
    
private:
    
    typedef enum RequestType
    {
        RequestTypeTile,
        RequestTypeOther
    } RequestType;

    MapManager *mapManager;
    NSString *VectorToUrTileName( NSString *urlStr );
    //NSData *LoadURTileNamed( NSString *tileName );
    RequestType RequestTypeForResouce( const Resource& resource );
    std::unique_ptr<AsyncRequest> TileRequest(const Resource&, Callback);
    std::unique_ptr<AsyncRequest> OtherRequest(const Resource&, Callback);
};
    
    
URTFileSource::Impl::Impl()
{
    mapManager = [MapManager sharedInstance];
}


URTFileSource::Impl::RequestType URTFileSource::Impl::RequestTypeForResouce( const Resource& resource )
{
    NSString *urlStr = @(resource.url.c_str());
    NSRange vectorpbfrange = [urlStr rangeOfString:@".vector.pbf"];
    if ( vectorpbfrange.location == NSNotFound )
    {
        return RequestTypeOther;
    }
    
    return RequestTypeTile;
}


std::unique_ptr<AsyncRequest> URTFileSource::Impl::request(const Resource& resource, Callback callback)
{
    RequestType requestType = RequestTypeForResouce( resource );
    
    switch ( requestType )
    {
        case RequestTypeTile:
            return TileRequest(resource, callback);
        case RequestTypeOther:
            return OtherRequest(resource, callback);
            break;
        default:
            assert( false );
    }
    
    
}
    
    
std::unique_ptr<AsyncRequest> URTFileSource::Impl::TileRequest(const Resource& resource, Callback callback)
{
    NSString *urlStr = @(resource.url.c_str());
    NSString *urTileName = VectorToUrTileName(urlStr);
    
    assert ( urTileName != nil );
    
    auto request = std::make_unique<URTRequest>(callback);
    auto shared = request->shared; // Explicit copy so that it also gets copied into the completion handler block below.
    
    [mapManager getTilesOrProxiesNamed:urTileName callingBlock:^( NSArray *maptiles )
    {
        Response response;

        response.data = std::make_shared<std::string>("Use tileArray parameter");
        response.urtTile = std::make_shared<UrtTileData>((__bridge_retained void *) maptiles, (__bridge_retained void *) urTileName);
        shared->notify(response);
    }];


    return std::move(request);
}
    
    
NSString *MapboxUrlStringToFilename( NSString *urlString )
{
    if ( urlString.length < 10 )
    {
        return nil;
    }
    
    if ( [urlString compare:@"mapbox://" options:0 range:NSMakeRange(0, 9)] != NSOrderedSame )
    {
        return nil;
    }
    
    NSString *onlyPath = [urlString substringFromIndex:9];
    NSString *targetFilename = [onlyPath stringByReplacingOccurrencesOfString:@"/" withString:@"-"];
    NSString *singleEncoding = [targetFilename stringByReplacingOccurrencesOfString:@"%25" withString:@"%"];
    
    return [@"RESOURCE-" stringByAppendingString:singleEncoding];
}
    
    
std::unique_ptr<AsyncRequest> URTFileSource::Impl::OtherRequest(const Resource& resource, Callback callback)
{
    NSString *urlStr = @(resource.url.c_str());
    NSString *filename = MapboxUrlStringToFilename(urlStr);
    
    Response response;
    
    if ( filename == nil )
    {
        NSLog(@"URTFileSource::Impl::OtherRequest - parts != 2");
        response.error = std::make_unique<Response::Error>(Response::Error::Reason::Other, "Not in bundle resources" );
        callback(response);
        return nullptr;
    }
    
    NSURL *bundleUrl = [[NSBundle mainBundle] URLForResource:filename withExtension:nil];
    NSData *data = [NSData dataWithContentsOfURL:bundleUrl];
    
    if ( data != nil )
    {
        response.data = std::make_shared<std::string>((const char *)[data bytes], [data length]);
        callback( response );
        
        auto req = std::make_unique<AsyncRequest>();
        return req;
    }
    
    NSURL *bundleUrlZ = [[NSBundle mainBundle] URLForResource:filename withExtension:@"z"];
    NSData *compressedData = [NSData dataWithContentsOfURL:bundleUrlZ];
    
    if ( compressedData != nil )
    {
        std::string compressedStr((const char *)[compressedData bytes], [compressedData length]);
        std::stringstream compressedStream ( compressedStr );
        boost::iostreams::filtering_streambuf<boost::iostreams::input> in;
        in.push(boost::iostreams::gzip_decompressor());
        in.push(compressedStream);
        
        std::stringstream dst;
        boost::iostreams::filtering_streambuf<boost::iostreams::output> out(dst);
        
        boost::iostreams::copy(in, out);
        
        response.data = std::make_shared<std::string>(dst.str());
        callback( response );
        
        auto req = std::make_unique<AsyncRequest>();
        return req;
    }

    
    // URL base: https://api.mapbox.com/fonts/v1/mapbox/DIN%20Offc%20Pro%20Regular%2cArial%20Unicode%20MS%20Regular/8192-8447.pbf?access_token=pk.eyJ1IjoicmF5aHVudGVydWsiLCJhIjoiY2lmMnF5bzZ5MDBqaHN2bHlheXV0djZ2OCJ9.aJKNtMIdNxgbz_2PDjr_fg&events=true
    NSLog( @"Missing request data!!! URL was %@", urlStr );
    response.error = std::make_unique<Response::Error>(Response::Error::Reason::Other, "Could not load resource" );
    callback(response);
    return nullptr;    
}

    
NSString *URTFileSource::Impl::VectorToUrTileName( NSString *urlStr )
{
    NSRange vectorpbfrange = [urlStr rangeOfString:@".vector.pbf"];
    if ( vectorpbfrange.location == NSNotFound )
    {
        return nil;
    }
    
    NSRange streetsRange = [urlStr rangeOfString:@"mapbox-streets-v7/"];
    if ( streetsRange.location == NSNotFound )
    {
        return nil;
    }
    
    NSInteger tilenameStart = streetsRange.location + streetsRange.length;
    NSInteger tilenameEnd = vectorpbfrange.location;
    NSRange tilenameRange = NSMakeRange(streetsRange.location + streetsRange.length, tilenameEnd-tilenameStart);
    
    NSString *tilename = [urlStr substringWithRange:tilenameRange];
    NSArray *components = [tilename componentsSeparatedByString:@"/"];
    
    assert ( components.count == 3 );
    
    NSInteger z = [components[0] integerValue];
    NSInteger x = [components[1] integerValue];
    NSInteger y = [components[2] integerValue];
    
    NSMutableString *result = [NSMutableString string];
    
    for ( NSInteger i = 0; i < z; i++ )
    {
        NSInteger tx = ( x >> ( z - i - 1) ) & 0x01;
        NSInteger ty = ( y >> ( z - i - 1) ) & 0x01;
        
        if ( tx == 0 )
        {
            [result appendString:ty == 0 ? @"b" : @"d"];
        }
        else
        {
            //NSAssert(tx == 1, @"tx should be 0 or 1");
            [result appendString:ty == 0 ? @"a" : @"c"];
        }
    }
    
    //NSLog(@"Translated %ld/%ld/%ld to %@", (long)z, (long)x, (long)y, result);
    
    return result;
}


/*NSData *LoadURTileNamed(NSString *tileName)
{
    NSURL *docsUrl = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
    NSURL *fullReplacementUrl = [docsUrl URLByAppendingPathComponent:tileName];
    NSData *replacementData = [NSData dataWithContentsOfURL:fullReplacementUrl];
    return replacementData;
}*/

    
URTFileSource::URTFileSource() : impl( std::unique_ptr<URTFileSource::Impl>(new URTFileSource::Impl) )
{
    
}

URTFileSource::~URTFileSource()
{
    
}

    
std::unique_ptr<AsyncRequest> URTFileSource::request(const Resource& resource, Callback callback)
{
    return impl->request(resource, callback);
}
    

}
