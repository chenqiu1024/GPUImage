//
//  SubtitleAndAudioSelectionViewController.m
//  PlayerCamera
//
//  Created by DOM QIU on 2018/7/8.
//  Copyright © 2018 DOM QIU. All rights reserved.
//

#import "SubtitleAndAudioSelectionViewController.h"
#import "IJKGPUImageMovie.h"

static NSString* SelectionTableViewHeaderIdentifier = @"SelectionTableViewHeaderIdentifier";
static NSString* SelectionTableViewCellIdentifier = @"SelectionTableViewCellIdentifier";
static NSString* SelectionTableViewButtonCellIdentifier = @"SelectionTableViewButtonCellIdentifier";

@interface SubtitleAndAudioSelectionViewController ()
{
    NSMutableArray<NSString* >* _audios;
    NSMutableArray<NSString* >* _subtitles;
    NSMutableDictionary<NSNumber*, NSNumber* >* _audioIndex2StreamIndex;
    NSMutableDictionary<NSNumber*, NSNumber* >* _subtitleIndex2StreamIndex;
    NSInteger _selectedAudio;
    NSInteger _selectedSubtitle;
    void(^_selectedHandler)(NSInteger);
    void(^_completion)();
}

@end

@implementation SubtitleAndAudioSelectionViewController

-(void) setDataSource:(NSDictionary*)mediaMeta {
    [_audios removeAllObjects];
    [_subtitles removeAllObjects];
    [_audioIndex2StreamIndex removeAllObjects];
    [_subtitleIndex2StreamIndex removeAllObjects];
    NSArray<NSDictionary* >* streams = [mediaMeta objectForKey:kk_IJKM_KEY_STREAMS];
    NSInteger streamIndex = 0;
    for (NSDictionary* stream in streams)
    {
        NSString* type = [stream objectForKey:k_IJKM_KEY_TYPE];
        NSString* title = [stream objectForKey:k_IJKM_KEY_TITLE];
        if ([type isEqualToString:@IJKM_VAL_TYPE__AUDIO] && title)
        {
            [_audioIndex2StreamIndex setObject:@(streamIndex) forKey:@(_audios.count)];
            [_audios addObject:title];
        }
        if ([type isEqualToString:@IJKM_VAL_TYPE__TIMEDTEXT] && title)
        {
            [_subtitleIndex2StreamIndex setObject:@(streamIndex) forKey:@(_subtitles.count)];
            [_subtitles addObject:title];
        }
        streamIndex++;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.tableView reloadData];
    });
}

- (instancetype)initWithStyle:(UITableViewStyle)style dataSource:(NSDictionary*)mediaMeta selectedAudioStream:(NSInteger)selectedAudioStream selectedSubtitleStream:(NSInteger)selectedSubtitleStream selectedHandler:(void(^)(NSInteger))selectedHandler completion:(void(^)())completion {
    if (self = [super initWithStyle:style])
    {
        _audios = [[NSMutableArray alloc] init];
        _subtitles = [[NSMutableArray alloc] init];
        _audioIndex2StreamIndex = [[NSMutableDictionary alloc] init];
        _subtitleIndex2StreamIndex = [[NSMutableDictionary alloc] init];
        _selectedAudio = selectedAudioStream;
        _selectedSubtitle = selectedSubtitleStream;
        _completion = completion;
        _selectedHandler = selectedHandler;
        [self setDataSource:mediaMeta];
    }
    return self;
}

-(void) viewDidLoad {
    [super viewDidLoad];
    //    self.automaticallyAdjustsScrollViewInsets = YES;
    //    self.edgesForExtendedLayout = UIRectEdgeNone;
    //    self.extendedLayoutIncludesOpaqueBars = NO;
    self.tableView.contentInset = UIEdgeInsetsMake(20.0f, 0.0f, 0.0f, 0.0f);
}

-(NSInteger) audioSection {
    if (!_audios || 0 == _audios.count)
        return -1;
    else
        return 0;
}

-(NSInteger) subtitleSection {
    if (!_subtitles || 0 == _subtitles.count)
        return -1;
    else
        return [self audioSection] + 1;
}

-(NSInteger) confirmButtonSection {
    return [self subtitleSection] + 1;
}

-(NSInteger) numberOfSectionsInTableView:(UITableView *)tableView {
    return [self confirmButtonSection] + 1;
}

-(NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == [self audioSection])
        return _audios.count;
    else if (section == [self subtitleSection])
        return _subtitles.count;
    return 1;
}

-(CGFloat) tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    if (section == [self audioSection])
        return 24.f;
    else if (section == [self subtitleSection])
        return 24.f;
    return 0;
}

-(NSString*) tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == [self audioSection])
        return @"Audio(s):";
    else if (section == [self subtitleSection])
        return @"Subtitle(s):";
    return nil;
}

-(UITableViewCell*) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString* identifier = (indexPath.section != 2 ? SelectionTableViewCellIdentifier : SelectionTableViewButtonCellIdentifier);
    UITableViewCell* cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell)
    {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:identifier];
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    }
    cell.textLabel.textAlignment = NSTextAlignmentLeft;
    if (indexPath.section == [self audioSection])
    {
        cell.textLabel.text = _audios[indexPath.row];
        NSNumber* streamIndex = [_audioIndex2StreamIndex objectForKey:@(indexPath.row)];
        if (streamIndex.integerValue == _selectedAudio)
        {
            cell.accessoryType = UITableViewCellAccessoryCheckmark;
        }
        else
        {
            cell.accessoryType = UITableViewCellAccessoryNone;
        }
    }
    else if (indexPath.section == [self subtitleSection])
    {
        cell.textLabel.text = _subtitles[indexPath.row];
        NSNumber* streamIndex = [_subtitleIndex2StreamIndex objectForKey:@(indexPath.row)];
        if (streamIndex.integerValue == _selectedSubtitle)
        {
            cell.accessoryType = UITableViewCellAccessoryCheckmark;
        }
        else
        {
            cell.accessoryType = UITableViewCellAccessoryNone;
        }
    }
    else if (indexPath.section == [self confirmButtonSection])
    {
        UILabel* label = [[UILabel alloc] init];
        label.text = @"OK";
        [label sizeToFit];
        label.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
        [cell.contentView addSubview:label];
        [label setCenter:cell.contentView.center];
        //            cell.textLabel.textAlignment = NSTextAlignmentCenter;
        //            cell.textLabel.text = @"OK";
    }
    return cell;
}

-(void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([self audioSection] == indexPath.section)
    {
        NSNumber* streamIndex = [_audioIndex2StreamIndex objectForKey:@(indexPath.row)];
        _selectedAudio = streamIndex.integerValue;
        if (_selectedHandler)
        {
            _selectedHandler(_selectedAudio);
        }
    }
    else if ([self subtitleSection] == indexPath.section)
    {
        NSNumber* streamIndex = [_subtitleIndex2StreamIndex objectForKey:@(indexPath.row)];
        _selectedSubtitle = streamIndex.integerValue;
        if (_selectedHandler)
        {
            _selectedHandler(_selectedSubtitle);
        }
    }
    else if ([self confirmButtonSection] == indexPath.section)
    {
        [self dismissViewControllerAnimated:NO completion:^{
            if (_completion)
            {
                _completion();
            }
        }];
    }
    [tableView reloadData];
}

@end
