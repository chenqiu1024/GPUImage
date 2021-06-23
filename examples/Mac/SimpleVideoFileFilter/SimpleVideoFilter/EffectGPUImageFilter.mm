//
//  EffectGPUImageFilter.m
//  SimpleVideoFileFilter
//
//  Created by qiudong on 2021/6/23.
//  Copyright © 2021 Red Queen Coder, LLC. All rights reserved.
//

#import "EffectGPUImageFilter.h"
#import "bef_effect_api.h"
#import <string>
#import <iostream>
#import <vector>
#import <map>
#import <sys/stat.h>
#import <unistd.h>
#import <dirent.h>

void getDirNames(std::string path, std::vector<std::string>& fileNames)
{
    DIR *pDir;
    struct dirent* ptr;
    if (!(pDir = opendir(path.c_str())))
    {
        std::cout << "Folder doesn't Exist!" << std::endl;
        return;
    }

    const char* curStr = nullptr;
    while ((ptr = readdir(pDir)) != 0)
    {
        curStr = ptr->d_name;
        if (strcmp(curStr, ".") != 0 && strcmp(curStr, "..") != 0 && strcmp(curStr, ".DS_Store"))
        {
            fileNames.push_back(path + "/" + curStr);
        }
    }
    closedir(pDir);
}

std::string getModelDir()
{
    static NSString* bundlePath = [[NSBundle mainBundle] pathForResource:@"EffectResources" ofType:@"bundle"];
    static NSString* modelsPath = [bundlePath stringByAppendingPathComponent:@"model"];
    return modelsPath.UTF8String;
}

char* modelFinder(void* effectHandle, const char* dirPath, const char* modelName)
{
    static bool s_isMapComputed = false;
    static const std::string SCHEME_FILE = "file://";
    std::string modelFilePath = getModelDir();
    static std::map<std::string, std::string> s_modelFileMap;

    if (!s_isMapComputed)
    {
        std::vector<std::string> modelFileVtr;
        getDirNames(modelFilePath, modelFileVtr);

        for (const auto& modelFile: modelFileVtr)
        {
            const size_t substrIdx = modelFile.find_last_of('/');
            const std::string modelKey = substrIdx == std::string::npos ?  modelFile : modelFile.substr(substrIdx+1);
            s_modelFileMap[modelKey] = SCHEME_FILE + modelFile;
        }
        s_isMapComputed = true;
    }

    std::string curPath = modelName;
    int idx = (int)curPath.find_last_of('/');
    std::string curModelName = curPath.substr(idx + 1);

    if (s_modelFileMap.count(curModelName))
        return const_cast<char *>(s_modelFileMap[curModelName].c_str());
    else
    {
//        auto resourceFinder = effectplatform::algorithmutil::getResourceFinder();
//        return resourceFinder.finder(effectHandle, dirPath, modelName);
        return nullptr;
    }
}

@interface EffectGPUImageFilter ()
{
    bef_effect_handle_t _effectHandle;
}
@end

@implementation EffectGPUImageFilter

-(instancetype) init {
    if (self = [super init])
    {
        bef_effect_create_handle(&_effectHandle, false);
        bef_effect_use_pipeline_processor(_effectHandle, false);
            bef_effect_set_render_api(_effectHandle, bef_render_api_gles30);
            bef_effect_init_with_resource_finder_v2(_effectHandle, 1280, 720, modelFinder, nullptr ,"MacOS");

//            bef_effect_composer_set_mode(_effectHandle, 1, 0);//A+B+C
            bef_effect_set_camera_device_position(_effectHandle, bef_camera_position_front);

            bool enable_new_algorithm = true;
            bef_effect_config_ab_value("enable_new_algorithm_system", &enable_new_algorithm, BEF_AB_DATA_TYPE_BOOL);
    }
    return self;
}

@end
