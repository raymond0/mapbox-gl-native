//
//  UrtAutoFileSource.cpp
//  ios
//
//  Created by Ray Hunter on 27/03/2017.
//  Copyright © 2017 Mapbox. All rights reserved.
//

#include "urt_auto_file_source.hpp"
#include <mbgl/platform/darwin/reachability.h>
#include <mbgl/storage/network_status.hpp>
#import "Foundation/Foundation.h"
#import "UrtFile/UrtFile.h"

namespace mbgl {

static NSString * const MGLOfflineStorageFileName = @"cache.db";

NSURL *cacheURLIncludingSubdirectory(BOOL useSubdirectory)
{
    NSURL *cacheDirectoryURL = [[NSFileManager defaultManager] URLForDirectory:NSApplicationSupportDirectory
                                                                      inDomain:NSUserDomainMask
                                                             appropriateForURL:nil
                                                                        create:YES
                                                                         error:nil];
    NSString *bundleIdentifier = [NSBundle mainBundle].bundleIdentifier;

    cacheDirectoryURL = [cacheDirectoryURL URLByAppendingPathComponent:bundleIdentifier];
    if (useSubdirectory) {
        cacheDirectoryURL = [cacheDirectoryURL URLByAppendingPathComponent:@".mapbox"];
    }
    [[NSFileManager defaultManager] createDirectoryAtURL:cacheDirectoryURL
                             withIntermediateDirectories:YES
                                              attributes:nil
                                                   error:nil];
    if (useSubdirectory) {
        // Avoid backing up the offline cache onto iCloud, because it can be
        // redownloaded. Ideally, we’d even put the ambient cache in Caches, so
        // it can be reclaimed by the system when disk space runs low. But
        // unfortunately it has to live in the same file as offline resources.
        [cacheDirectoryURL setResourceValue:@YES forKey:NSURLIsExcludedFromBackupKey error:NULL];
    }
    return [cacheDirectoryURL URLByAppendingPathComponent:MGLOfflineStorageFileName];
}


URTAutoFileSource::URTAutoFileSource()
{
    NSURL *cacheURL = cacheURLIncludingSubdirectory(YES);
    NSString *cachePath = cacheURL.path ?: @"";
    
    NSString *accessToken = @"pk.eyJ1IjoicmF5aHVudGVydWsiLCJhIjoiY2lmMnF5bzZ5MDBqaHN2bHlheXV0djZ2OCJ9.aJKNtMIdNxgbz_2PDjr_fg";
    
    m_default_file_source = new mbgl::DefaultFileSource(cachePath.UTF8String, [NSBundle mainBundle].resourceURL.path.UTF8String);
    m_default_file_source->setAccessToken(accessToken.UTF8String);
    m_default_file_source->setAPIBaseURL(mbgl::util::API_BASE_URL);

    m_urt_file_source = new URTFileSource;
    
    reach = [MGLReachability reachabilityForInternetConnection];
    m_online = reach.currentReachabilityStatus != NotReachable;
    
    reach.reachableBlock = ^(MGLReachability*)
    {
        m_online = true;
    };
    reach.unreachableBlock = ^(MGLReachability*)
    {
        m_online = false;
    };
    
    [reach startNotifier];
}


URTAutoFileSource::~URTAutoFileSource()
{
    delete m_default_file_source;
    m_default_file_source = nullptr;
    delete m_urt_file_source;
    m_urt_file_source = nullptr;
}
    
    
class URTAutoRequest : public AsyncRequest {
public:
    URTAutoRequest()
    {
        onlineRequest = nullptr;
        offlineRequest = std::make_shared<std::unique_ptr<AsyncRequest>>(nullptr);
    }
    
    ~URTAutoRequest() override
    {
        
    }
    
    std::unique_ptr<AsyncRequest> onlineRequest;
    std::shared_ptr<std::unique_ptr<AsyncRequest>> offlineRequest;
    
private:
};

    
std::unique_ptr<AsyncRequest> URTAutoFileSource::request(const Resource& resource, Callback callback)
{
    if ( MRInDrivingMode && resource.tileData->z == 15 )
    {
        return m_urt_file_source->request(resource, callback);
    }
    
    if ( ! m_online )
    {
        //
        //  Stop mix of online cache and pure offline as they don't look the same
        //
        return m_urt_file_source->request(resource, callback);
    }
    
    std::unique_ptr<URTAutoRequest> autoRequest = std::make_unique<URTAutoRequest>();
    std::weak_ptr<std::unique_ptr<AsyncRequest>> offlineRequest = autoRequest->offlineRequest;
    const Resource copyResource = resource;
    
    auto onlineReq = m_default_file_source->request(resource, [this, &resource, callback, offlineRequest, copyResource](Response res)
    {
        if ( res.error == nullptr )
        {
            callback( res );
            return;
        }
        
        if (auto olr = offlineRequest.lock())
        {
            auto offlineReq = m_urt_file_source->request(copyResource, callback);
            *olr = std::move(offlineReq);
        }
    });
    
    autoRequest->onlineRequest = std::move(onlineReq);
    offlineRequest = autoRequest->offlineRequest;
    
    return std::move(autoRequest);
}

    
}