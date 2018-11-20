import Foundation

private let fallbackDict: [String: String] = {
    guard let mainPath = Bundle.main.path(forResource: "en", ofType: "lproj"), let bundle = Bundle(path: mainPath) else {
        return [:]
    }
    guard let path = bundle.path(forResource: "Localizable", ofType: "strings") else {
        return [:]
    }
    guard let dict = NSDictionary(contentsOf: URL(fileURLWithPath: path)) as? [String: String] else {
        return [:]
    }
    return dict
}()

private extension PluralizationForm {
    var canonicalSuffix: String {
        switch self {
            case .zero:
                return "_0"
            case .one:
                return "_1"
            case .two:
                return "_2"
            case .few:
                return "_3_10"
            case .many:
                return "_many"
            case .other:
                return "_any"
        }
    }
}

public final class PresentationStringsComponent {
    public let languageCode: String
    public let localizedName: String
    public let pluralizationRulesCode: String?
    public let dict: [String: String]
    
    public init(languageCode: String, localizedName: String, pluralizationRulesCode: String?, dict: [String: String]) {
        self.languageCode = languageCode
        self.localizedName = localizedName
        self.pluralizationRulesCode = pluralizationRulesCode
        self.dict = dict
    }
}
        
private func getValue(_ primaryComponent: PresentationStringsComponent, _ secondaryComponent: PresentationStringsComponent?, _ key: String) -> String {
    if let value = primaryComponent.dict[key] {
        return value
    } else if let secondaryComponent = secondaryComponent, let value = secondaryComponent.dict[key] {
        return value
    } else if let value = fallbackDict[key] {
        return value
    } else {
        return key
    }
}

private func getValueWithForm(_ primaryComponent: PresentationStringsComponent, _ secondaryComponent: PresentationStringsComponent?, _ key: String, _ form: PluralizationForm) -> String {
    let builtKey = key + form.canonicalSuffix
    if let value = primaryComponent.dict[builtKey] {
        return value
    } else if let secondaryComponent = secondaryComponent, let value = secondaryComponent.dict[builtKey] {
        return value
    } else if let value = fallbackDict[builtKey] {
        return value
    }
    return key
}
        
private let argumentRegex = try! NSRegularExpression(pattern: "%(((\\d+)\\$)?)([@df])", options: [])
private func extractArgumentRanges(_ value: String) -> [(Int, NSRange)] {
    var result: [(Int, NSRange)] = []
    let string = value as NSString
    let matches = argumentRegex.matches(in: string as String, options: [], range: NSRange(location: 0, length: string.length))
    var index = 0
    for match in matches {
        var currentIndex = index
        if match.range(at: 3).location != NSNotFound {
            currentIndex = Int(string.substring(with: match.range(at: 3)))! - 1
        }
        result.append((currentIndex, match.range(at: 0)))
        index += 1
    }
    result.sort(by: { $0.1.location < $1.1.location })
    return result
}
    
func formatWithArgumentRanges(_ value: String, _ ranges: [(Int, NSRange)], _ arguments: [String]) -> (String, [(Int, NSRange)]) {
    let string = value as NSString
    
    var resultingRanges: [(Int, NSRange)] = []

    var currentLocation = 0

    let result = NSMutableString()
    for (index, range) in ranges {
        if currentLocation < range.location {
            result.append(string.substring(with: NSRange(location: currentLocation, length: range.location - currentLocation)))
        }
        resultingRanges.append((index, NSRange(location: result.length, length: (arguments[index] as NSString).length)))
        result.append(arguments[index])
        currentLocation = range.location + range.length
    }
    if currentLocation != string.length {
        result.append(string.substring(with: NSRange(location: currentLocation, length: string.length - currentLocation)))
    }
    return (result as String, resultingRanges)
}
        
private final class DataReader {
    private let data: Data
    private var ptr: Int = 0

    init(_ data: Data) {
        self.data = data
    }

    func readInt32() -> Int32 {
        assert(self.ptr + 4 <= self.data.count)
        let result = self.data.withUnsafeBytes { (bytes: UnsafePointer<Int8>) -> Int32 in
            var value: Int32 = 0
            memcpy(&value, bytes.advanced(by: self.ptr), 4)
            return value
        }
        self.ptr += 4
        return result
    }

    func readString() -> String {
        let length = Int(self.readInt32())
        assert(self.ptr + length <= self.data.count)
        let value = String(data: self.data.subdata(in: self.ptr ..< self.ptr + length), encoding: .utf8)!
        self.ptr += length
        return value
    }
}
        
private func loadMapping() -> ([Int], [String], [Int], [Int], [String]) {
    guard let filePath = frameworkBundle.path(forResource: "PresentationStrings", ofType: "mapping") else {
        fatalError()
    }
    guard let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)) else {
        fatalError()
    }

    let reader = DataReader(data)

    let idCount = Int(reader.readInt32())
    var sIdList: [Int] = []
    var sKeyList: [String] = []
    var sArgIdList: [Int] = []
    for _ in 0 ..< idCount {
        let id = Int(reader.readInt32())
        sIdList.append(id)
        sKeyList.append(reader.readString())
        if reader.readInt32() != 0 {
            sArgIdList.append(id)
        }
    }

    let pCount = Int(reader.readInt32())
    var pIdList: [Int] = []
    var pKeyList: [String] = []
    for _ in 0 ..< Int(pCount) {
        pIdList.append(Int(reader.readInt32()))
        pKeyList.append(reader.readString())
    }

    return (sIdList, sKeyList, sArgIdList, pIdList, pKeyList)
}

private let keyMapping: ([Int], [String], [Int], [Int], [String]) = loadMapping()
        
public final class PresentationStrings {
    public let lc: UInt32
    
    public let primaryComponent: PresentationStringsComponent
    public let secondaryComponent: PresentationStringsComponent?
    public let baseLanguageCode: String
        
    private let _s: [Int: String]
    private let _r: [Int: [(Int, NSRange)]]
    private let _ps: [Int: String]
    public var Channel_BanUser_Title: String { return self._s[0]! }
    public var Notification_SecretChatMessageScreenshotSelf: String { return self._s[1]! }
    public var Preview_SaveGif: String { return self._s[2]! }
    public var Passport_ScanPassportHelp: String { return self._s[3]! }
    public var EnterPasscode_EnterNewPasscodeNew: String { return self._s[4]! }
    public var Passport_Identity_TypeInternalPassport: String { return self._s[5]! }
    public var Privacy_Calls_WhoCanCallMe: String { return self._s[6]! }
    public var Passport_DeletePassport: String { return self._s[7]! }
    public var Watch_NoConnection: String { return self._s[8]! }
    public var Activity_UploadingPhoto: String { return self._s[9]! }
    public var PrivacySettings_PrivacyTitle: String { return self._s[10]! }
    public func DialogList_PinLimitError(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[11]!, self._r[11]!, [_0])
    }
    public var FastTwoStepSetup_PasswordSection: String { return self._s[12]! }
    public var FastTwoStepSetup_EmailSection: String { return self._s[13]! }
    public var Notifications_Badge_IncludeChannels: String { return self._s[14]! }
    public var Cache_ClearCache: String { return self._s[15]! }
    public var Common_Close: String { return self._s[16]! }
    public var Passport_PasswordDescription: String { return self._s[17]! }
    public var ChangePhoneNumberCode_Called: String { return self._s[20]! }
    public var Login_PhoneTitle: String { return self._s[21]! }
    public func Cache_Clear(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[22]!, self._r[22]!, [_0])
    }
    public var EnterPasscode_EnterNewPasscodeChange: String { return self._s[23]! }
    public var Watch_ChatList_Compose: String { return self._s[24]! }
    public var DialogList_SearchSectionDialogs: String { return self._s[26]! }
    public var Contacts_TabTitle: String { return self._s[27]! }
    public var NotificationsSound_Pulse: String { return self._s[28]! }
    public var Passport_Language_el: String { return self._s[29]! }
    public var Passport_Identity_DateOfBirth: String { return self._s[30]! }
    public var TwoStepAuth_SetupPasswordConfirmPassword: String { return self._s[31]! }
    public var SocksProxySetup_PasteFromClipboard: String { return self._s[32]! }
    public var ChannelIntro_Text: String { return self._s[33]! }
    public var PrivacySettings_SecurityTitle: String { return self._s[34]! }
    public var DialogList_SavedMessages: String { return self._s[35]! }
    public var Update_Skip: String { return self._s[36]! }
    public func Call_StatusOngoing(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[37]!, self._r[37]!, [_0])
    }
    public var Settings_LogoutConfirmationText: String { return self._s[38]! }
    public var Passport_Identity_ResidenceCountry: String { return self._s[40]! }
    public var AutoNightTheme_ScheduledTo: String { return self._s[41]! }
    public var SocksProxySetup_RequiredCredentials: String { return self._s[42]! }
    public var BlockedUsers_Info: String { return self._s[43]! }
    public var ChatSettings_AutomaticAudioDownload: String { return self._s[44]! }
    public var Settings_SetUsername: String { return self._s[45]! }
    public var Privacy_Calls_CustomShareHelp: String { return self._s[46]! }
    public var Group_MessagePhotoUpdated: String { return self._s[47]! }
    public var Message_PinnedInvoice: String { return self._s[48]! }
    public var Login_InfoAvatarAdd: String { return self._s[49]! }
    public var Conversation_RestrictedMedia: String { return self._s[51]! }
    public var AutoDownloadSettings_LimitBySize: String { return self._s[52]! }
    public var WebSearch_RecentSectionTitle: String { return self._s[53]! }
    public func CHAT_MESSAGE_TEXT(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[54]!, self._r[54]!, [_1, _2, _3])
    }
    public var Message_Sticker: String { return self._s[55]! }
    public var Paint_Regular: String { return self._s[56]! }
    public var Channel_Username_Help: String { return self._s[57]! }
    public func Profile_CreateEncryptedChatOutdatedError(_ _0: String, _ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[58]!, self._r[58]!, [_0, _1])
    }
    public var PrivacyPolicy_DeclineLastWarning: String { return self._s[59]! }
    public var Passport_FieldEmail: String { return self._s[60]! }
    public var ContactInfo_PhoneLabelPager: String { return self._s[62]! }
    public func PINNED_STICKER(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[63]!, self._r[63]!, [_1, _2])
    }
    public var AutoDownloadSettings_Title: String { return self._s[64]! }
    public var Conversation_ShareInlineBotLocationConfirmation: String { return self._s[65]! }
    public func Channel_AdminLog_MessageEdited(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[66]!, self._r[66]!, [_0])
    }
    public var Group_Setup_HistoryHidden: String { return self._s[67]! }
    public var Watch_Message_Game: String { return self._s[68]! }
    public func PHONE_CALL_REQUEST(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[70]!, self._r[70]!, [_1])
    }
    public var AccessDenied_MicrophoneRestricted: String { return self._s[71]! }
    public var Your_cards_expiration_year_is_invalid: String { return self._s[72]! }
    public var GroupInfo_InviteByLink: String { return self._s[74]! }
    public func Notification_LeftChat(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[75]!, self._r[75]!, [_0])
    }
    public var Appearance_AutoNightThemeDisabled: String { return self._s[76]! }
    public func Channel_AdminLog_MessageAdmin(_ _0: String, _ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[77]!, self._r[77]!, [_0, _1, _2])
    }
    public var PrivacyLastSeenSettings_NeverShareWith_Placeholder: String { return self._s[78]! }
    public var Notifications_ExceptionsMessagePlaceholder: String { return self._s[82]! }
    public var NotificationsSound_Alert: String { return self._s[83]! }
    public var TwoStepAuth_SetupEmail: String { return self._s[84]! }
    public var Checkout_PayWithFaceId: String { return self._s[85]! }
    public var Login_ResetAccountProtected_Reset: String { return self._s[88]! }
    public var SocksProxySetup_Hostname: String { return self._s[89]! }
    public func PrivacyPolicy_AgeVerificationMessage(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[90]!, self._r[90]!, [_0])
    }
    public var NotificationsSound_None: String { return self._s[91]! }
    public var Channel_AdminLog_CanEditMessages: String { return self._s[93]! }
    public func MESSAGE_CONTACT(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[94]!, self._r[94]!, [_1])
    }
    public var MediaPicker_MomentsDateRangeSameMonthYearFormat: String { return self._s[95]! }
    public var Notification_MessageLifetime1w: String { return self._s[97]! }
    public var PasscodeSettings_AutoLock_IfAwayFor_5minutes: String { return self._s[98]! }
    public var ChatSettings_Groups: String { return self._s[100]! }
    public var State_Connecting: String { return self._s[101]! }
    public func Message_ForwardedMessageShort(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[102]!, self._r[102]!, [_0])
    }
    public var Watch_ConnectionDescription: String { return self._s[103]! }
    public var TwoStepAuth_ReEnterPasswordDescription: String { return self._s[104]! }
    public func Notification_CallTimeFormat(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[105]!, self._r[105]!, [_1, _2])
    }
    public var Passport_Identity_Selfie: String { return self._s[106]! }
    public var Passport_Identity_GenderMale: String { return self._s[107]! }
    public var Paint_Delete: String { return self._s[108]! }
    public var Passport_Identity_AddDriversLicense: String { return self._s[109]! }
    public var Passport_Language_ne: String { return self._s[110]! }
    public var Channel_MessagePhotoUpdated: String { return self._s[111]! }
    public var Passport_Address_OneOfTypePassportRegistration: String { return self._s[112]! }
    public var Cache_Help: String { return self._s[113]! }
    public var SocksProxySetup_ProxyStatusConnected: String { return self._s[115]! }
    public func Login_EmailPhoneBody(_ _0: String, _ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[116]!, self._r[116]!, [_0, _1, _2])
    }
    public var Checkout_ShippingAddress: String { return self._s[118]! }
    public var Channel_BanList_RestrictedTitle: String { return self._s[119]! }
    public var Checkout_TotalAmount: String { return self._s[120]! }
    public var Appearance_TextSize: String { return self._s[121]! }
    public var Passport_Address_TypeResidentialAddress: String { return self._s[122]! }
    public var Conversation_MessageEditedLabel: String { return self._s[123]! }
    public var SharedMedia_EmptyLinksText: String { return self._s[124]! }
    public func Conversation_RestrictedTextTimed(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[125]!, self._r[125]!, [_0])
    }
    public var Passport_Address_AddResidentialAddress: String { return self._s[126]! }
    public var Calls_NoCallsPlaceholder: String { return self._s[127]! }
    public var Passport_Address_AddPassportRegistration: String { return self._s[128]! }
    public var Conversation_PinMessageAlert_OnlyPin: String { return self._s[129]! }
    public var PasscodeSettings_UnlockWithFaceId: String { return self._s[130]! }
    public var ContactInfo_Title: String { return self._s[131]! }
    public var ReportPeer_ReasonOther_Send: String { return self._s[133]! }
    public var Notifications_Badge: String { return self._s[135]! }
    public var Conversation_InstantPagePreview: String { return self._s[136]! }
    public var PasscodeSettings_SimplePasscodeHelp: String { return self._s[137]! }
    public func Time_PreciseDate_m9(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[138]!, self._r[138]!, [_1, _2, _3])
    }
    public var GroupInfo_Title: String { return self._s[140]! }
    public var State_Updating: String { return self._s[142]! }
    public var PrivacyPolicy_AgeVerificationAgree: String { return self._s[143]! }
    public var Map_GetDirections: String { return self._s[144]! }
    public func TwoStepAuth_PendingEmailHelp(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[145]!, self._r[145]!, [_0])
    }
    public var UserInfo_PhoneCall: String { return self._s[147]! }
    public var Passport_Language_bn: String { return self._s[149]! }
    public var MusicPlayer_VoiceNote: String { return self._s[150]! }
    public var Paint_Duplicate: String { return self._s[151]! }
    public var Channel_Username_InvalidTaken: String { return self._s[152]! }
    public var Conversation_ClearGroupHistory: String { return self._s[153]! }
    public var Passport_Address_OneOfTypeRentalAgreement: String { return self._s[154]! }
    public var Stickers_GroupStickersHelp: String { return self._s[157]! }
    public var SecretChat_Title: String { return self._s[158]! }
    public var Group_UpgradeConfirmation: String { return self._s[159]! }
    public var Checkout_LiabilityAlertTitle: String { return self._s[160]! }
    public var GroupInfo_GroupNamePlaceholder: String { return self._s[162]! }
    public func Time_PreciseDate_m11(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[164]!, self._r[164]!, [_1, _2, _3])
    }
    public var Passport_DeletePersonalDetailsConfirmation: String { return self._s[165]! }
    public func UserInfo_NotificationsDefaultSound(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[166]!, self._r[166]!, [_0])
    }
    public var Passport_Email_Help: String { return self._s[167]! }
    public func MESSAGE_GEOLIVE(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[169]!, self._r[169]!, [_1])
    }
    public func Notification_JoinedGroupByLink(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[170]!, self._r[170]!, [_0])
    }
    public var LoginPassword_Title: String { return self._s[171]! }
    public var Login_HaveNotReceivedCodeInternal: String { return self._s[172]! }
    public var PasscodeSettings_SimplePasscode: String { return self._s[174]! }
    public var NewContact_Title: String { return self._s[175]! }
    public var Username_CheckingUsername: String { return self._s[176]! }
    public var Login_ResetAccountProtected_TimerTitle: String { return self._s[177]! }
    public var Checkout_Email: String { return self._s[178]! }
    public var CheckoutInfo_SaveInfo: String { return self._s[179]! }
    public var UserInfo_InviteBotToGroup: String { return self._s[180]! }
    public func ChangePhoneNumberCode_CallTimer(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[181]!, self._r[181]!, [_0])
    }
    public var TwoStepAuth_SetupPasswordEnterPasswordNew: String { return self._s[182]! }
    public var Weekday_Wednesday: String { return self._s[183]! }
    public func Channel_AdminLog_MessageToggleSignaturesOff(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[184]!, self._r[184]!, [_0])
    }
    public var Month_ShortDecember: String { return self._s[185]! }
    public var Channel_SignMessages: String { return self._s[186]! }
    public var Appearance_Title: String { return self._s[187]! }
    public var ReportPeer_ReasonCopyright: String { return self._s[188]! }
    public var Conversation_Moderate_Delete: String { return self._s[189]! }
    public var Conversation_CloudStorage_ChatStatus: String { return self._s[190]! }
    public var Login_InfoTitle: String { return self._s[192]! }
    public var Privacy_GroupsAndChannels_NeverAllow_Placeholder: String { return self._s[193]! }
    public var Message_Video: String { return self._s[194]! }
    public var Notification_ChannelInviterSelf: String { return self._s[195]! }
    public var Channel_AdminLog_BanEmbedLinks: String { return self._s[196]! }
    public var Conversation_SecretLinkPreviewAlert: String { return self._s[197]! }
    public func CHANNEL_MESSAGE_GEOLIVE(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[199]!, self._r[199]!, [_1])
    }
    public var Cache_Videos: String { return self._s[200]! }
    public var Call_ReportSkip: String { return self._s[201]! }
    public var NetworkUsageSettings_MediaImageDataSection: String { return self._s[202]! }
    public var Group_Setup_HistoryTitle: String { return self._s[203]! }
    public var TwoStepAuth_GenericHelp: String { return self._s[204]! }
    public func DialogList_SingleRecordingAudioSuffix(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[205]!, self._r[205]!, [_0])
    }
    public var Privacy_TopPeersDelete: String { return self._s[206]! }
    public var Checkout_NewCard_CardholderNameTitle: String { return self._s[208]! }
    public var Settings_FAQ_Button: String { return self._s[209]! }
    public func GroupInfo_AddParticipantConfirmation(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[210]!, self._r[210]!, [_0])
    }
    public func Notification_PinnedLiveLocationMessage(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[213]!, self._r[213]!, [_0])
    }
    public var AccessDenied_PhotosRestricted: String { return self._s[214]! }
    public var Map_Locating: String { return self._s[215]! }
    public var AutoDownloadSettings_Unlimited: String { return self._s[216]! }
    public var Passport_Language_km: String { return self._s[217]! }
    public var MediaPicker_LivePhotoDescription: String { return self._s[218]! }
    public var Passport_DiscardMessageDescription: String { return self._s[219]! }
    public var SocksProxySetup_Title: String { return self._s[222]! }
    public var SharedMedia_EmptyMusicText: String { return self._s[223]! }
    public var Cache_ByPeerHeader: String { return self._s[225]! }
    public var Bot_GroupStatusReadsHistory: String { return self._s[226]! }
    public var TwoStepAuth_ResetAccountConfirmation: String { return self._s[227]! }
    public var CallSettings_Always: String { return self._s[228]! }
    public var Message_ImageExpired: String { return self._s[229]! }
    public var Channel_BanUser_Unban: String { return self._s[231]! }
    public var Stickers_GroupChooseStickerPack: String { return self._s[232]! }
    public var Group_Setup_TypePrivate: String { return self._s[233]! }
    public var Passport_Language_cs: String { return self._s[234]! }
    public var Settings_LogoutConfirmationTitle: String { return self._s[235]! }
    public var UserInfo_FirstNamePlaceholder: String { return self._s[236]! }
    public var Passport_Identity_SurnamePlaceholder: String { return self._s[237]! }
    public var Passport_Identity_FilesView: String { return self._s[238]! }
    public var LoginPassword_ResetAccount: String { return self._s[239]! }
    public var Privacy_GroupsAndChannels_AlwaysAllow: String { return self._s[240]! }
    public func Notification_JoinedChat(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[242]!, self._r[242]!, [_0])
    }
    public var Notifications_ExceptionsUnmuted: String { return self._s[243]! }
    public var ChannelInfo_DeleteChannel: String { return self._s[244]! }
    public var Passport_Title: String { return self._s[246]! }
    public var NetworkUsageSettings_BytesReceived: String { return self._s[247]! }
    public var BlockedUsers_BlockTitle: String { return self._s[248]! }
    public var Update_Title: String { return self._s[250]! }
    public var AccessDenied_PhotosAndVideos: String { return self._s[251]! }
    public var Channel_Username_Title: String { return self._s[252]! }
    public func Channel_AdminLog_MessageToggleSignaturesOn(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[253]!, self._r[253]!, [_0])
    }
    public var Map_PullUpForPlaces: String { return self._s[254]! }
    public func Conversation_EncryptionWaiting(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[255]!, self._r[255]!, [_0])
    }
    public var Passport_Language_ka: String { return self._s[256]! }
    public var InfoPlist_NSSiriUsageDescription: String { return self._s[257]! }
    public var Calls_NotNow: String { return self._s[258]! }
    public var Conversation_Report: String { return self._s[259]! }
    public func CHANNEL_MESSAGE_DOC(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[260]!, self._r[260]!, [_1])
    }
    public var Channel_AdminLogFilter_EventsAll: String { return self._s[261]! }
    public var InfoPlist_NSLocationWhenInUseUsageDescription: String { return self._s[262]! }
    public var Passport_Address_TypeTemporaryRegistration: String { return self._s[263]! }
    public var TwoStepAuth_EmailChangeSuccess: String { return self._s[266]! }
    public var Call_ConnectionErrorTitle: String { return self._s[267]! }
    public var Passport_Language_tr: String { return self._s[268]! }
    public var Settings_ApplyProxyAlertEnable: String { return self._s[271]! }
    public var Settings_ChatSettings: String { return self._s[272]! }
    public var Group_About_Help: String { return self._s[273]! }
    public func CHANNEL_MESSAGE_NOTEXT(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[274]!, self._r[274]!, [_1])
    }
    public var Month_GenSeptember: String { return self._s[275]! }
    public var PrivacySettings_LastSeenEverybody: String { return self._s[276]! }
    public var Contacts_NotRegisteredSection: String { return self._s[277]! }
    public var PhotoEditor_BlurToolRadial: String { return self._s[278]! }
    public var TwoStepAuth_PasswordRemoveConfirmation: String { return self._s[279]! }
    public var Channel_EditAdmin_PermissionEditMessages: String { return self._s[282]! }
    public var TwoStepAuth_ChangePassword: String { return self._s[283]! }
    public var Watch_MessageView_Title: String { return self._s[284]! }
    public func Notification_PinnedRoundMessage(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[285]!, self._r[285]!, [_0])
    }
    public var Conversation_ViewMessage: String { return self._s[286]! }
    public var Passport_FieldEmailHelp: String { return self._s[287]! }
    public var Settings_SaveEditedPhotos: String { return self._s[288]! }
    public var Channel_Management_LabelCreator: String { return self._s[289]! }
    public func Notification_PinnedStickerMessage(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[290]!, self._r[290]!, [_0])
    }
    public func AutoNightTheme_AutomaticHelp(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[291]!, self._r[291]!, [_0])
    }
    public var Passport_Address_EditPassportRegistration: String { return self._s[293]! }
    public var PhotoEditor_QualityTool: String { return self._s[294]! }
    public var Login_NetworkError: String { return self._s[295]! }
    public var TwoStepAuth_EnterPasswordForgot: String { return self._s[296]! }
    public var Compose_ChannelMembers: String { return self._s[298]! }
    public func Channel_AdminLog_CaptionEdited(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[299]!, self._r[299]!, [_0])
    }
    public var Common_Yes: String { return self._s[300]! }
    public var KeyCommand_JumpToPreviousUnreadChat: String { return self._s[301]! }
    public var CheckoutInfo_ReceiverInfoPhone: String { return self._s[302]! }
    public var SocksProxySetup_TypeNone: String { return self._s[303]! }
    public var GroupInfo_AddParticipantTitle: String { return self._s[305]! }
    public var Map_LiveLocationShowAll: String { return self._s[306]! }
    public var Settings_SavedMessages: String { return self._s[307]! }
    public var Passport_FieldIdentitySelfieHelp: String { return self._s[308]! }
    public func CHANNEL_MESSAGE_TEXT(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[310]!, self._r[310]!, [_1, _2])
    }
    public var Checkout_PayNone: String { return self._s[311]! }
    public var CheckoutInfo_ErrorNameInvalid: String { return self._s[312]! }
    public var Notification_PaymentSent: String { return self._s[313]! }
    public var Settings_Username: String { return self._s[314]! }
    public var Notification_CallMissedShort: String { return self._s[315]! }
    public var Call_CallInProgressTitle: String { return self._s[316]! }
    public var Passport_Scans: String { return self._s[318]! }
    public var PhotoEditor_Skip: String { return self._s[320]! }
    public var AuthSessions_TerminateOtherSessionsHelp: String { return self._s[321]! }
    public var Call_AudioRouteHeadphones: String { return self._s[322]! }
    public var SocksProxySetup_UseForCalls: String { return self._s[323]! }
    public var Contacts_InviteFriends: String { return self._s[324]! }
    public var Channel_BanUser_PermissionSendMessages: String { return self._s[325]! }
    public var Notifications_InAppNotificationsVibrate: String { return self._s[326]! }
    public var StickerPack_Share: String { return self._s[327]! }
    public var Watch_MessageView_Reply: String { return self._s[328]! }
    public var Call_AudioRouteSpeaker: String { return self._s[329]! }
    public var Checkout_Title: String { return self._s[333]! }
    public func MESSAGE_GEO(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[334]!, self._r[334]!, [_1])
    }
    public var Privacy_Calls: String { return self._s[335]! }
    public var DialogList_AdLabel: String { return self._s[336]! }
    public var Passport_Identity_ScansHelp: String { return self._s[337]! }
    public var Channel_AdminLogFilter_EventsInfo: String { return self._s[338]! }
    public var Passport_Language_hu: String { return self._s[339]! }
    public func Channel_AdminLog_MessagePinned(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[340]!, self._r[340]!, [_0])
    }
    public func Channel_AdminLog_MessageToggleInvitesOn(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[341]!, self._r[341]!, [_0])
    }
    public var KeyCommand_ScrollDown: String { return self._s[343]! }
    public var Conversation_LinkDialogSave: String { return self._s[344]! }
    public var CheckoutInfo_ErrorShippingNotAvailable: String { return self._s[345]! }
    public var Conversation_SendMessageErrorFlood: String { return self._s[348]! }
    public func Checkout_SavePasswordTimeoutAndTouchId(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[349]!, self._r[349]!, [_0])
    }
    public var HashtagSearch_AllChats: String { return self._s[350]! }
    public var InfoPlist_NSPhotoLibraryAddUsageDescription: String { return self._s[351]! }
    public func Date_ChatDateHeaderYear(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[354]!, self._r[354]!, [_1, _2, _3])
    }
    public var Privacy_Calls_P2PContacts: String { return self._s[355]! }
    public var Passport_Email_Delete: String { return self._s[356]! }
    public var CheckoutInfo_ShippingInfoCountry: String { return self._s[357]! }
    public var Map_ShowPlaces: String { return self._s[358]! }
    public var Passport_Identity_GenderFemale: String { return self._s[359]! }
    public var ApplyLanguage_ChangeLanguageAction: String { return self._s[360]! }
    public var Camera_VideoMode: String { return self._s[361]! }
    public func Watch_Time_ShortFullAt(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[362]!, self._r[362]!, [_1, _2])
    }
    public var UserInfo_TelegramCall: String { return self._s[365]! }
    public var PrivacyLastSeenSettings_CustomShareSettingsHelp: String { return self._s[366]! }
    public var Passport_UpdateRequiredError: String { return self._s[368]! }
    public var Channel_AdminLog_InfoPanelAlertText: String { return self._s[371]! }
    public func Channel_AdminLog_MessageUnpinned(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[373]!, self._r[373]!, [_0])
    }
    public var Cache_Photos: String { return self._s[374]! }
    public var Message_PinnedStickerMessage: String { return self._s[375]! }
    public var PhotoEditor_QualityMedium: String { return self._s[376]! }
    public var Privacy_PaymentsClearInfo: String { return self._s[377]! }
    public var PhotoEditor_CurvesRed: String { return self._s[379]! }
    public var Passport_Identity_AddPersonalDetails: String { return self._s[380]! }
    public func Login_WillCallYou(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[382]!, self._r[382]!, [_0])
    }
    public var Privacy_PaymentsTitle: String { return self._s[383]! }
    public var SocksProxySetup_ProxyType: String { return self._s[384]! }
    public func Time_PreciseDate_m8(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[385]!, self._r[385]!, [_1, _2, _3])
    }
    public var Login_PhoneNumberHelp: String { return self._s[386]! }
    public var User_DeletedAccount: String { return self._s[388]! }
    public var Call_StatusFailed: String { return self._s[389]! }
    public func Notification_GroupInviter(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[390]!, self._r[390]!, [_0])
    }
    public var Localization_ChooseLanguage: String { return self._s[391]! }
    public var CheckoutInfo_ShippingInfoAddress2Placeholder: String { return self._s[392]! }
    public func Notification_SecretChatMessageScreenshot(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[393]!, self._r[393]!, [_0])
    }
    public func DialogList_SingleUploadingPhotoSuffix(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[394]!, self._r[394]!, [_0])
    }
    public var Channel_LeaveChannel: String { return self._s[395]! }
    public var Compose_NewGroup: String { return self._s[397]! }
    public var TwoStepAuth_EmailPlaceholder: String { return self._s[398]! }
    public var PhotoEditor_ExposureTool: String { return self._s[399]! }
    public var Conversation_ViewChannel: String { return self._s[400]! }
    public var ChatAdmins_AdminLabel: String { return self._s[403]! }
    public var Contacts_FailedToSendInvitesMessage: String { return self._s[404]! }
    public var Login_Code: String { return self._s[405]! }
    public var Passport_Identity_ExpiryDateNone: String { return self._s[406]! }
    public var ContactInfo_PhoneLabelWorkFax: String { return self._s[407]! }
    public var AuthSessions_IncompleteAttemptsInfo: String { return self._s[408]! }
    public var Channel_Username_InvalidCharacters: String { return self._s[411]! }
    public var FeatureDisabled_Oops: String { return self._s[412]! }
    public var Calls_CallTabTitle: String { return self._s[413]! }
    public var ShareMenu_Send: String { return self._s[414]! }
    public var WatchRemote_AlertTitle: String { return self._s[415]! }
    public var Channel_Members_AddBannedErrorAdmin: String { return self._s[416]! }
    public var Conversation_InfoGroup: String { return self._s[417]! }
    public var Passport_Identity_TypePersonalDetails: String { return self._s[418]! }
    public var Passport_Identity_OneOfTypePassport: String { return self._s[419]! }
    public var Checkout_Phone: String { return self._s[420]! }
    public var Channel_SignMessages_Help: String { return self._s[422]! }
    public var Passport_PasswordNext: String { return self._s[423]! }
    public var Calls_SubmitRating: String { return self._s[424]! }
    public var Camera_FlashOn: String { return self._s[425]! }
    public var Watch_MessageView_Forward: String { return self._s[426]! }
    public var Passport_DiscardMessageTitle: String { return self._s[428]! }
    public var Passport_Language_uk: String { return self._s[429]! }
    public var GroupInfo_ActionPromote: String { return self._s[430]! }
    public var DialogList_You: String { return self._s[431]! }
    public var Weekday_Monday: String { return self._s[432]! }
    public var Passport_Identity_SelfieHelp: String { return self._s[433]! }
    public var Passport_Identity_MiddleName: String { return self._s[435]! }
    public var AccessDenied_Camera: String { return self._s[436]! }
    public var WatchRemote_NotificationText: String { return self._s[437]! }
    public var SharedMedia_ViewInChat: String { return self._s[438]! }
    public var Passcode_AppLockedAlert: String { return self._s[439]! }
    public var Activity_RecordingAudio: String { return self._s[442]! }
    public var Watch_Stickers_StickerPacks: String { return self._s[443]! }
    public func Target_ShareGameConfirmationPrivate(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[444]!, self._r[444]!, [_0])
    }
    public var Checkout_NewCard_PostcodePlaceholder: String { return self._s[445]! }
    public var Passport_Identity_OneOfTypeInternalPassport: String { return self._s[446]! }
    public var DialogList_DeleteConversationConfirmation: String { return self._s[447]! }
    public var AttachmentMenu_SendAsFile: String { return self._s[448]! }
    public var Watch_Conversation_Unblock: String { return self._s[451]! }
    public var Channel_AdminLog_MessagePreviousLink: String { return self._s[452]! }
    public var TextFormat_Monospace: String { return self._s[453]! }
    public var Conversation_ContextMenuCopy: String { return self._s[454]! }
    public var GroupInfo_UpgradeButton: String { return self._s[455]! }
    public var PrivacyLastSeenSettings_NeverShareWith: String { return self._s[457]! }
    public var ConvertToSupergroup_HelpText: String { return self._s[459]! }
    public var MediaPicker_VideoMuteDescription: String { return self._s[460]! }
    public var Passport_Address_TypeRentalAgreement: String { return self._s[461]! }
    public var Passport_Language_it: String { return self._s[463]! }
    public var UserInfo_ShareMyContactInfo: String { return self._s[464]! }
    public var Channel_Info_Stickers: String { return self._s[465]! }
    public var Appearance_ColorTheme: String { return self._s[466]! }
    public func FileSize_GB(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[468]!, self._r[468]!, [_0])
    }
    public func Passport_FieldOneOf_Or(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[470]!, self._r[470]!, [_1, _2])
    }
    public var Month_ShortJanuary: String { return self._s[472]! }
    public var Channel_BanUser_PermissionsHeader: String { return self._s[473]! }
    public var PhotoEditor_QualityVeryHigh: String { return self._s[474]! }
    public var Passport_Language_mk: String { return self._s[475]! }
    public var AuthSessions_IncompleteAttempts: String { return self._s[476]! }
    public var Login_TermsOfServiceLabel: String { return self._s[477]! }
    public func InstantPage_RelatedArticleAuthorAndDateTitle(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[478]!, self._r[478]!, [_1, _2])
    }
    public func MESSAGE_TEXT(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[480]!, self._r[480]!, [_1, _2])
    }
    public var DialogList_NoMessagesTitle: String { return self._s[481]! }
    public var Passport_DeletePassportConfirmation: String { return self._s[482]! }
    public var Passport_Language_az: String { return self._s[484]! }
    public var AccessDenied_Contacts: String { return self._s[485]! }
    public var Your_cards_security_code_is_invalid: String { return self._s[486]! }
    public var Contacts_InviteSearchLabel: String { return self._s[487]! }
    public var Tour_StartButton: String { return self._s[488]! }
    public var CheckoutInfo_Title: String { return self._s[490]! }
    public var Conversation_Admin: String { return self._s[491]! }
    public func Channel_AdminLog_MessageRestrictedNameUsername(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[493]!, self._r[493]!, [_1, _2])
    }
    public var ChangePhoneNumberCode_Help: String { return self._s[494]! }
    public var Web_Error: String { return self._s[495]! }
    public var ShareFileTip_Title: String { return self._s[496]! }
    public var Privacy_SecretChatsLinkPreviews: String { return self._s[497]! }
    public var Username_InvalidStartsWithNumber: String { return self._s[498]! }
    public func DialogList_EncryptedChatStartedIncoming(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[500]!, self._r[500]!, [_0])
    }
    public var Calls_AddTab: String { return self._s[502]! }
    public var DialogList_AdNoticeAlert: String { return self._s[503]! }
    public var PhotoEditor_TiltShift: String { return self._s[506]! }
    public var Passport_Identity_TypeDriversLicenseUploadScan: String { return self._s[507]! }
    public var ChannelMembers_WhoCanAddMembers_Admins: String { return self._s[508]! }
    public var Tour_Text5: String { return self._s[509]! }
    public var Notifications_ExceptionsGroupPlaceholder: String { return self._s[510]! }
    public var Watch_Stickers_RecentPlaceholder: String { return self._s[511]! }
    public var Common_Select: String { return self._s[512]! }
    public func Notification_MessageLifetimeRemoved(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[513]!, self._r[513]!, [_1])
    }
    public func PINNED_INVOICE(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[514]!, self._r[514]!, [_1])
    }
    public var Month_GenFebruary: String { return self._s[515]! }
    public var Contacts_SelectAll: String { return self._s[516]! }
    public var FastTwoStepSetup_EmailHelp: String { return self._s[517]! }
    public var Month_GenOctober: String { return self._s[518]! }
    public var CheckoutInfo_ErrorPhoneInvalid: String { return self._s[519]! }
    public var Passport_Identity_DocumentNumberPlaceholder: String { return self._s[520]! }
    public var AutoNightTheme_UpdateLocation: String { return self._s[521]! }
    public var Group_Setup_TypePublic: String { return self._s[523]! }
    public var Checkout_PaymentMethod_New: String { return self._s[524]! }
    public var ShareMenu_Comment: String { return self._s[525]! }
    public var Passport_FloodError: String { return self._s[526]! }
    public var Channel_Management_LabelEditor: String { return self._s[527]! }
    public var TwoStepAuth_SetPasswordHelp: String { return self._s[528]! }
    public var Channel_AdminLogFilter_EventsTitle: String { return self._s[529]! }
    public var NotificationSettings_ContactJoined: String { return self._s[531]! }
    public var ChatSettings_AutoDownloadVideos: String { return self._s[532]! }
    public var Passport_Identity_TypeIdentityCard: String { return self._s[534]! }
    public var Username_LinkCopied: String { return self._s[536]! }
    public func Time_MonthOfYear_m9(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[537]!, self._r[537]!, [_0])
    }
    public var Channel_EditAdmin_PermissionAddAdmins: String { return self._s[539]! }
    public var Passport_FieldPhoneHelp: String { return self._s[540]! }
    public var Conversation_SendMessage: String { return self._s[541]! }
    public var Notification_CallIncoming: String { return self._s[542]! }
    public func MESSAGE_FWDS(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[543]!, self._r[543]!, [_1, _2])
    }
    public var Map_OpenInYandexMaps: String { return self._s[546]! }
    public var FastTwoStepSetup_PasswordHelp: String { return self._s[547]! }
    public var GroupInfo_GroupHistoryHidden: String { return self._s[548]! }
    public var AutoNightTheme_UseSunsetSunrise: String { return self._s[549]! }
    public var Month_ShortNovember: String { return self._s[550]! }
    public var AccessDenied_Settings: String { return self._s[553]! }
    public var EncryptionKey_Title: String { return self._s[554]! }
    public var Profile_MessageLifetime1h: String { return self._s[555]! }
    public func Map_DistanceAway(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[556]!, self._r[556]!, [_0])
    }
    public var Checkout_ErrorPaymentFailed: String { return self._s[557]! }
    public var Compose_NewMessage: String { return self._s[558]! }
    public var Conversation_LiveLocationYou: String { return self._s[559]! }
    public var Privacy_TopPeersHelp: String { return self._s[560]! }
    public var Map_OpenInWaze: String { return self._s[561]! }
    public var Checkout_ShippingMethod: String { return self._s[562]! }
    public var Login_InfoFirstNamePlaceholder: String { return self._s[563]! }
    public var Checkout_ErrorProviderAccountInvalid: String { return self._s[564]! }
    public var CallSettings_TabIconDescription: String { return self._s[566]! }
    public var ChatSettings_AutoDownloadReset: String { return self._s[567]! }
    public var Checkout_WebConfirmation_Title: String { return self._s[568]! }
    public var PasscodeSettings_AutoLock: String { return self._s[569]! }
    public var Notifications_MessageNotificationsPreview: String { return self._s[572]! }
    public var Conversation_BlockUser: String { return self._s[573]! }
    public func TwoStepAuth_SetupPendingEmail(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[574]!, self._r[574]!, [_0])
    }
    public var Passport_Identity_EditPassport: String { return self._s[575]! }
    public var MessageTimer_Custom: String { return self._s[576]! }
    public var Conversation_SilentBroadcastTooltipOff: String { return self._s[578]! }
    public var Conversation_Mute: String { return self._s[579]! }
    public var CreateGroup_SoftUserLimitAlert: String { return self._s[580]! }
    public var AccessDenied_LocationDenied: String { return self._s[581]! }
    public var Tour_Title6: String { return self._s[582]! }
    public var Settings_UsernameEmpty: String { return self._s[583]! }
    public var PrivacySettings_TwoStepAuth: String { return self._s[584]! }
    public var Conversation_FileICloudDrive: String { return self._s[585]! }
    public var KeyCommand_SendMessage: String { return self._s[587]! }
    public func Channel_AdminLog_MessageDeleted(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[589]!, self._r[589]!, [_0])
    }
    public var DialogList_DeleteBotConfirmation: String { return self._s[590]! }
    public var EditProfile_Title: String { return self._s[591]! }
    public var PasscodeSettings_HelpTop: String { return self._s[592]! }
    public var SocksProxySetup_ProxySocks5: String { return self._s[593]! }
    public var Common_TakePhotoOrVideo: String { return self._s[594]! }
    public var Notification_MessageLifetime2s: String { return self._s[595]! }
    public var Checkout_ErrorGeneric: String { return self._s[596]! }
    public var DialogList_Unread: String { return self._s[598]! }
    public var AutoNightTheme_Automatic: String { return self._s[599]! }
    public var Passport_Identity_Name: String { return self._s[600]! }
    public var Channel_AdminLog_CanBanUsers: String { return self._s[602]! }
    public var Cache_Indexing: String { return self._s[603]! }
    public func ENCRYPTION_REQUEST(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[605]!, self._r[605]!, [_1])
    }
    public var StickerSettings_ContextInfo: String { return self._s[606]! }
    public var Channel_BanUser_PermissionEmbedLinks: String { return self._s[607]! }
    public var Map_Location: String { return self._s[608]! }
    public var GroupInfo_InviteLink_LinkSection: String { return self._s[609]! }
    public func Passport_Identity_UploadOneOfScan(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[610]!, self._r[610]!, [_0])
    }
    public var Notification_PassportValuePhone: String { return self._s[611]! }
    public var TwoStepAuth_PasswordChangeSuccess: String { return self._s[612]! }
    public var Privacy_Calls_AlwaysAllow_Placeholder: String { return self._s[613]! }
    public var CheckoutInfo_ShippingInfoPostcode: String { return self._s[614]! }
    public var Group_Setup_HistoryVisibleHelp: String { return self._s[615]! }
    public func Time_PreciseDate_m7(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[617]!, self._r[617]!, [_1, _2, _3])
    }
    public var PasscodeSettings_EncryptDataHelp: String { return self._s[618]! }
    public var Passport_Language_ja: String { return self._s[620]! }
    public var KeyCommand_FocusOnInputField: String { return self._s[621]! }
    public var Channel_Members_AddAdminErrorBlacklisted: String { return self._s[622]! }
    public var Cache_KeepMedia: String { return self._s[623]! }
    public var SocksProxySetup_ProxyTelegram: String { return self._s[625]! }
    public var WebPreview_GettingLinkInfo: String { return self._s[626]! }
    public var Group_Setup_TypePublicHelp: String { return self._s[627]! }
    public var Map_Satellite: String { return self._s[628]! }
    public var Username_InvalidTaken: String { return self._s[629]! }
    public func Notification_PinnedAudioMessage(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[630]!, self._r[630]!, [_0])
    }
    public var Notification_MessageLifetime1d: String { return self._s[631]! }
    public var Profile_MessageLifetime2s: String { return self._s[632]! }
    public func TwoStepAuth_RecoveryEmailUnavailable(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[633]!, self._r[633]!, [_0])
    }
    public var Calls_RatingFeedback: String { return self._s[634]! }
    public var Profile_EncryptionKey: String { return self._s[635]! }
    public var Watch_Suggestion_WhatsUp: String { return self._s[636]! }
    public var LoginPassword_PasswordPlaceholder: String { return self._s[637]! }
    public var TwoStepAuth_EnterPasswordPassword: String { return self._s[638]! }
    public func Time_PreciseDate_m10(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[640]!, self._r[640]!, [_1, _2, _3])
    }
    public func CHANNEL_MESSAGE_CONTACT(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[641]!, self._r[641]!, [_1])
    }
    public var Passport_Language_bg: String { return self._s[642]! }
    public var PrivacySettings_DeleteAccountHelp: String { return self._s[644]! }
    public var Channel_Info_Banned: String { return self._s[647]! }
    public var Conversation_ShareBotContactConfirmationTitle: String { return self._s[648]! }
    public var ConversationProfile_UsersTooMuchError: String { return self._s[649]! }
    public var ChatAdmins_AllMembersAreAdminsOffHelp: String { return self._s[650]! }
    public var Privacy_GroupsAndChannels_WhoCanAddMe: String { return self._s[651]! }
    public var Login_CodeExpiredError: String { return self._s[653]! }
    public var Settings_PhoneNumber: String { return self._s[654]! }
    public var FastTwoStepSetup_EmailPlaceholder: String { return self._s[655]! }
    public func DialogList_MultipleTypingSuffix(_ _0: Int) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[656]!, self._r[656]!, ["\(_0)"])
    }
    public var Passport_Phone_Help: String { return self._s[657]! }
    public var Passport_Language_sl: String { return self._s[658]! }
    public var Bot_GenericBotStatus: String { return self._s[660]! }
    public var PrivacySettings_PasscodeAndTouchId: String { return self._s[661]! }
    public var Common_edit: String { return self._s[663]! }
    public var Settings_AppLanguage: String { return self._s[665]! }
    public var PrivacyLastSeenSettings_WhoCanSeeMyTimestamp: String { return self._s[666]! }
    public func Notification_Kicked(_ _0: String, _ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[669]!, self._r[669]!, [_0, _1])
    }
    public var Channel_AdminLog_MessageRestrictedForever: String { return self._s[671]! }
    public var Passport_DeleteDocument: String { return self._s[672]! }
    public var Notifications_ExceptionsResetToDefaults: String { return self._s[674]! }
    public var ChannelInfo_DeleteChannelConfirmation: String { return self._s[675]! }
    public var Passport_Address_OneOfTypeBankStatement: String { return self._s[677]! }
    public var Weekday_ShortSaturday: String { return self._s[678]! }
    public var Settings_Passport: String { return self._s[679]! }
    public var Share_AuthTitle: String { return self._s[680]! }
    public var Map_SendThisLocation: String { return self._s[681]! }
    public func Notification_PinnedDocumentMessage(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[682]!, self._r[682]!, [_0])
    }
    public var Passport_Identity_Surname: String { return self._s[683]! }
    public var Conversation_ContextMenuReply: String { return self._s[684]! }
    public var Channel_BanUser_PermissionSendMedia: String { return self._s[685]! }
    public var NetworkUsageSettings_Wifi: String { return self._s[687]! }
    public var Call_Accept: String { return self._s[688]! }
    public var GroupInfo_SetGroupPhotoDelete: String { return self._s[690]! }
    public var Login_PhoneBannedError: String { return self._s[691]! }
    public var Passport_Identity_DocumentDetails: String { return self._s[693]! }
    public var PhotoEditor_CropAuto: String { return self._s[695]! }
    public var PhotoEditor_ContrastTool: String { return self._s[696]! }
    public var CheckoutInfo_ReceiverInfoNamePlaceholder: String { return self._s[697]! }
    public var Passport_InfoLearnMore: String { return self._s[698]! }
    public var Channel_AdminLog_MessagePreviousCaption: String { return self._s[699]! }
    public func Passport_Email_UseTelegramEmail(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[700]!, self._r[700]!, [_0])
    }
    public var Privacy_PaymentsClear_ShippingInfo: String { return self._s[702]! }
    public var Passport_Email_UseTelegramEmailHelp: String { return self._s[703]! }
    public var UserInfo_NotificationsDefaultDisabled: String { return self._s[704]! }
    public var Date_DialogDateFormat: String { return self._s[706]! }
    public var Passport_Address_EditTemporaryRegistration: String { return self._s[707]! }
    public var ReportPeer_ReasonSpam: String { return self._s[708]! }
    public var Privacy_Calls_P2P: String { return self._s[709]! }
    public var Compose_TokenListPlaceholder: String { return self._s[710]! }
    public func PINNED_VIDEO(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[711]!, self._r[711]!, [_1])
    }
    public var StickerPacksSettings_Title: String { return self._s[713]! }
    public var Privacy_PaymentsClearInfoDoneHelp: String { return self._s[714]! }
    public var Privacy_Calls_NeverAllow_Placeholder: String { return self._s[715]! }
    public var Passport_PassportInformation: String { return self._s[716]! }
    public var Passport_Identity_OneOfTypeDriversLicense: String { return self._s[717]! }
    public var Settings_Support: String { return self._s[718]! }
    public var Notification_GroupInviterSelf: String { return self._s[720]! }
    public var TwoStepAuth_EmailAddSuccess: String { return self._s[721]! }
    public func SecretImage_NotViewedYet(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[722]!, self._r[722]!, [_0])
    }
    public var MaskStickerSettings_Title: String { return self._s[724]! }
    public var TwoStepAuth_SetPassword: String { return self._s[727]! }
    public func Passport_AcceptHelp(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[729]!, self._r[729]!, [_1, _2])
    }
    public var SocksProxySetup_SavedProxies: String { return self._s[730]! }
    public var GroupInfo_InviteLink_ShareLink: String { return self._s[731]! }
    public var Common_Cancel: String { return self._s[732]! }
    public var UserInfo_About_Placeholder: String { return self._s[734]! }
    public var Passport_Identity_NativeNameGenericTitle: String { return self._s[738]! }
    public var ApplyLanguage_ApplySuccess: String { return self._s[739]! }
    public var Notifications_ChannelNotificationsPreview: String { return self._s[740]! }
    public var Camera_Discard: String { return self._s[741]! }
    public var TextFormat_Italic: String { return self._s[742]! }
    public var ChangePhoneNumberCode_RequestingACall: String { return self._s[743]! }
    public var PrivacyLastSeenSettings_NeverShareWith_Title: String { return self._s[744]! }
    public var KeyCommand_JumpToNextChat: String { return self._s[746]! }
    public func Time_MonthOfYear_m8(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[750]!, self._r[750]!, [_0])
    }
    public var Tour_Text1: String { return self._s[751]! }
    public var Privacy_SecretChatsTitle: String { return self._s[752]! }
    public var Conversation_HoldForVideo: String { return self._s[753]! }
    public var Passport_Language_pt: String { return self._s[754]! }
    public var Checkout_NewCard_Title: String { return self._s[755]! }
    public var Channel_TitleInfo: String { return self._s[756]! }
    public var State_ConnectingToProxy: String { return self._s[757]! }
    public var Settings_About_Help: String { return self._s[758]! }
    public var AutoNightTheme_ScheduledFrom: String { return self._s[760]! }
    public var Passport_Language_tk: String { return self._s[761]! }
    public var Watch_Conversation_Reply: String { return self._s[762]! }
    public var ShareMenu_CopyShareLink: String { return self._s[763]! }
    public var Stickers_Search: String { return self._s[764]! }
    public var Notifications_GroupNotificationsExceptions: String { return self._s[765]! }
    public var Channel_Setup_TypePrivateHelp: String { return self._s[766]! }
    public var PhotoEditor_GrainTool: String { return self._s[767]! }
    public var Conversation_SearchByName_Placeholder: String { return self._s[768]! }
    public var Watch_Suggestion_TalkLater: String { return self._s[769]! }
    public var TwoStepAuth_ChangeEmail: String { return self._s[770]! }
    public var Passport_Identity_EditPersonalDetails: String { return self._s[771]! }
    public var Passport_FieldPhone: String { return self._s[773]! }
    public func ENCRYPTION_ACCEPT(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[774]!, self._r[774]!, [_1])
    }
    public var NetworkUsageSettings_BytesSent: String { return self._s[775]! }
    public var Conversation_ShareBotLocationConfirmationTitle: String { return self._s[776]! }
    public var Conversation_ForwardContacts: String { return self._s[778]! }
    public func Notification_ChangedGroupName(_ _0: String, _ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[779]!, self._r[779]!, [_0, _1])
    }
    public func MESSAGE_VIDEO(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[780]!, self._r[780]!, [_1])
    }
    public func Checkout_PayPrice(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[781]!, self._r[781]!, [_0])
    }
    public func Notification_PinnedTextMessage(_ _0: String, _ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[782]!, self._r[782]!, [_0, _1])
    }
    public var GroupInfo_InvitationLinkDoesNotExist: String { return self._s[784]! }
    public var ReportPeer_ReasonOther_Placeholder: String { return self._s[785]! }
    public var Wallpaper_Title: String { return self._s[787]! }
    public var PasscodeSettings_AutoLock_Disabled: String { return self._s[788]! }
    public var Watch_Compose_CreateMessage: String { return self._s[789]! }
    public var ChatSettings_ConnectionType_UseProxy: String { return self._s[790]! }
    public var Message_Audio: String { return self._s[792]! }
    public var Conversation_SearchNoResults: String { return self._s[794]! }
    public var PrivacyPolicy_Accept: String { return self._s[795]! }
    public var ReportPeer_ReasonViolence: String { return self._s[796]! }
    public var Group_Username_RemoveExistingUsernamesInfo: String { return self._s[797]! }
    public var Message_InvoiceLabel: String { return self._s[798]! }
    public var Channel_AdminLogFilter_Title: String { return self._s[799]! }
    public var Contacts_SearchLabel: String { return self._s[800]! }
    public var Group_Username_InvalidStartsWithNumber: String { return self._s[801]! }
    public var ChatAdmins_AllMembersAreAdminsOnHelp: String { return self._s[803]! }
    public var Month_ShortSeptember: String { return self._s[805]! }
    public var Group_Username_CreatePublicLinkHelp: String { return self._s[806]! }
    public var Login_CallRequestState2: String { return self._s[807]! }
    public var TwoStepAuth_RecoveryUnavailable: String { return self._s[809]! }
    public var Bot_Unblock: String { return self._s[810]! }
    public var SharedMedia_CategoryMedia: String { return self._s[811]! }
    public var Conversation_HoldForAudio: String { return self._s[812]! }
    public var Conversation_ClousStorageInfo_Description1: String { return self._s[814]! }
    public var Channel_Members_InviteLink: String { return self._s[815]! }
    public var Core_ServiceUserStatus: String { return self._s[816]! }
    public var WebSearch_RecentClearConfirmation: String { return self._s[817]! }
    public var Notification_ChannelMigratedFrom: String { return self._s[818]! }
    public var Settings_Title: String { return self._s[820]! }
    public var Call_StatusBusy: String { return self._s[821]! }
    public var ArchivedPacksAlert_Title: String { return self._s[822]! }
    public var ConversationMedia_Title: String { return self._s[823]! }
    public func Conversation_MessageViaUser(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[824]!, self._r[824]!, [_0])
    }
    public var Notification_PassportValueAddress: String { return self._s[825]! }
    public var Tour_Title4: String { return self._s[827]! }
    public var Call_StatusEnded: String { return self._s[828]! }
    public var Notifications_ChannelNotificationsAlert: String { return self._s[829]! }
    public var LiveLocationUpdated_JustNow: String { return self._s[830]! }
    public func Login_BannedPhoneSubject(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[831]!, self._r[831]!, [_0])
    }
    public var Passport_Address_EditResidentialAddress: String { return self._s[833]! }
    public func Channel_Management_RestrictedBy(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[834]!, self._r[834]!, [_0])
    }
    public var Conversation_UnpinMessageAlert: String { return self._s[835]! }
    public var NotificationsSound_Glass: String { return self._s[836]! }
    public var Passport_Address_Street1Placeholder: String { return self._s[838]! }
    public func Conversation_MessageDialogRetryAll(_ _1: Int) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[839]!, self._r[839]!, ["\(_1)"])
    }
    public func Checkout_PasswordEntry_Text(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[842]!, self._r[842]!, [_0])
    }
    public var Call_Message: String { return self._s[843]! }
    public var Contacts_MemberSearchSectionTitleGroup: String { return self._s[844]! }
    public func Conversation_BotInteractiveUrlAlert(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[845]!, self._r[845]!, [_0])
    }
    public var TwoStepAuth_SetupResendEmailCodeAlert: String { return self._s[846]! }
    public var GroupInfo_SharedMedia: String { return self._s[847]! }
    public func Time_PreciseDate_m6(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[848]!, self._r[848]!, [_1, _2, _3])
    }
    public var Channel_Username_InvalidStartsWithNumber: String { return self._s[849]! }
    public var KeyCommand_JumpToPreviousChat: String { return self._s[850]! }
    public var Conversation_Call: String { return self._s[851]! }
    public var KeyCommand_ScrollUp: String { return self._s[852]! }
    public func Privacy_GroupsAndChannels_InviteToChannelError(_ _0: String, _ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[853]!, self._r[853]!, [_0, _1])
    }
    public var AuthSessions_Sessions: String { return self._s[856]! }
    public var Document_TargetConfirmationFormat: String { return self._s[857]! }
    public var Group_Setup_TypeHeader: String { return self._s[858]! }
    public func DialogList_SinglePlayingGameSuffix(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[859]!, self._r[859]!, [_0])
    }
    public var AttachmentMenu_SendAsFiles: String { return self._s[860]! }
    public var Profile_MessageLifetime1m: String { return self._s[862]! }
    public var Passport_PasswordReset: String { return self._s[864]! }
    public var Settings_AppleWatch: String { return self._s[865]! }
    public var Passport_PasswordCompleteSetup: String { return self._s[867]! }
    public var Notifications_ExceptionsTitle: String { return self._s[868]! }
    public var Passport_Language_de: String { return self._s[869]! }
    public var Channel_AdminLog_MessagePreviousDescription: String { return self._s[870]! }
    public var Your_card_was_declined: String { return self._s[871]! }
    public var Notifications_DisplayNamesOnLockScreen: String { return self._s[872]! }
    public var PhoneNumberHelp_ChangeNumber: String { return self._s[874]! }
    public var ReportPeer_ReasonPornography: String { return self._s[875]! }
    public var Notification_CreatedChannel: String { return self._s[876]! }
    public var PhotoEditor_Original: String { return self._s[877]! }
    public var NotificationsSound_Chord: String { return self._s[878]! }
    public var Target_SelectGroup: String { return self._s[879]! }
    public var Stickers_SuggestAdded: String { return self._s[881]! }
    public var Channel_AdminLog_InfoPanelAlertTitle: String { return self._s[882]! }
    public var Notifications_GroupNotificationsPreview: String { return self._s[884]! }
    public var ChatSettings_AutoDownloadPhotos: String { return self._s[885]! }
    public var Message_PinnedLocationMessage: String { return self._s[887]! }
    public var Appearance_PreviewReplyText: String { return self._s[888]! }
    public var Passport_Address_Street2Placeholder: String { return self._s[889]! }
    public var Settings_Logout: String { return self._s[890]! }
    public func UserInfo_BlockConfirmation(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[891]!, self._r[891]!, [_0])
    }
    public var Profile_Username: String { return self._s[893]! }
    public var Group_Username_InvalidTooShort: String { return self._s[894]! }
    public var Appearance_AutoNightTheme: String { return self._s[895]! }
    public var AuthSessions_TerminateOtherSessions: String { return self._s[898]! }
    public var PasscodeSettings_TryAgainIn1Minute: String { return self._s[899]! }
    public var Privacy_TopPeers: String { return self._s[900]! }
    public var Passport_Phone_EnterOtherNumber: String { return self._s[901]! }
    public var NotificationsSound_Hello: String { return self._s[902]! }
    public var Notifications_InAppNotifications: String { return self._s[903]! }
    public func Notification_PassportValuesSentMessage(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[904]!, self._r[904]!, [_1, _2])
    }
    public var Passport_Language_is: String { return self._s[906]! }
    public var StickerPack_ViewPack: String { return self._s[907]! }
    public var EnterPasscode_ChangeTitle: String { return self._s[908]! }
    public var Call_Decline: String { return self._s[909]! }
    public var UserInfo_AddPhone: String { return self._s[911]! }
    public var AutoNightTheme_Title: String { return self._s[912]! }
    public var Activity_PlayingGame: String { return self._s[914]! }
    public var CheckoutInfo_ShippingInfoStatePlaceholder: String { return self._s[915]! }
    public var SaveIncomingPhotosSettings_From: String { return self._s[917]! }
    public var Passport_Address_TypeBankStatementUploadScan: String { return self._s[919]! }
    public var Notifications_MessageNotificationsSound: String { return self._s[920]! }
    public var Call_StatusWaiting: String { return self._s[921]! }
    public var Passport_Identity_MainPageHelp: String { return self._s[922]! }
    public var Weekday_ShortWednesday: String { return self._s[923]! }
    public var Notifications_Title: String { return self._s[924]! }
    public var PasscodeSettings_AutoLock_IfAwayFor_5hours: String { return self._s[925]! }
    public var Conversation_PinnedMessage: String { return self._s[927]! }
    public var Notifications_ChannelNotificationsHelp: String { return self._s[928]! }
    public func Time_MonthOfYear_m12(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[930]!, self._r[930]!, [_0])
    }
    public var ConversationProfile_LeaveDeleteAndExit: String { return self._s[931]! }
    public var State_connecting: String { return self._s[932]! }
    public var Channel_AdminLog_MessagePreviousMessage: String { return self._s[933]! }
    public var Passport_Scans_Upload: String { return self._s[935]! }
    public var AutoDownloadSettings_PhotosTitle: String { return self._s[936]! }
    public var Map_OpenInHereMaps: String { return self._s[937]! }
    public var Stickers_FavoriteStickers: String { return self._s[939]! }
    public var CheckoutInfo_Pay: String { return self._s[940]! }
    public var Passport_Identity_FrontSideHelp: String { return self._s[941]! }
    public var Update_UpdateApp: String { return self._s[942]! }
    public var Login_CountryCode: String { return self._s[943]! }
    public var PasscodeSettings_AutoLock_IfAwayFor_1hour: String { return self._s[944]! }
    public var CheckoutInfo_ShippingInfoState: String { return self._s[945]! }
    public func CHAT_MESSAGE_AUDIO(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[946]!, self._r[946]!, [_1, _2])
    }
    public var Login_SmsRequestState2: String { return self._s[947]! }
    public var Preview_SaveToCameraRoll: String { return self._s[948]! }
    public var SocksProxySetup_ProxyStatusConnecting: String { return self._s[949]! }
    public var Broadcast_AdminLog_EmptyText: String { return self._s[950]! }
    public var PasscodeSettings_ChangePasscode: String { return self._s[951]! }
    public var TwoStepAuth_RecoveryCodeInvalid: String { return self._s[952]! }
    public func Message_PaymentSent(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[953]!, self._r[953]!, [_0])
    }
    public var TwoStepAuth_RecoveryEmailChangeDescription: String { return self._s[955]! }
    public var Message_PinnedAudioMessage: String { return self._s[956]! }
    public var ChatSettings_ConnectionType_Title: String { return self._s[959]! }
    public func Conversation_RestrictedMediaTimed(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[961]!, self._r[961]!, [_0])
    }
    public var NotificationsSound_Complete: String { return self._s[962]! }
    public var NotificationsSound_Chime: String { return self._s[963]! }
    public var Login_InfoDeletePhoto: String { return self._s[964]! }
    public var ContactInfo_BirthdayLabel: String { return self._s[967]! }
    public var TwoStepAuth_RecoveryCodeExpired: String { return self._s[968]! }
    public var AutoDownloadSettings_Channels: String { return self._s[969]! }
    public var AutoDownloadSettings_Contacts: String { return self._s[971]! }
    public var TwoStepAuth_EmailTitle: String { return self._s[972]! }
    public var Passport_Email_EmailPlaceholder: String { return self._s[973]! }
    public var Channel_AdminLog_ChannelEmptyText: String { return self._s[974]! }
    public var Passport_Address_EditUtilityBill: String { return self._s[975]! }
    public var Privacy_GroupsAndChannels_NeverAllow: String { return self._s[976]! }
    public var Conversation_RestrictedStickers: String { return self._s[977]! }
    public var Conversation_AddContact: String { return self._s[978]! }
    public var Login_CancelPhoneVerificationContinue: String { return self._s[979]! }
    public func Time_MonthOfYear_m7(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[980]!, self._r[980]!, [_0])
    }
    public var PhotoEditor_QualityLow: String { return self._s[981]! }
    public var Paint_Outlined: String { return self._s[982]! }
    public var State_ConnectingToProxyInfo: String { return self._s[984]! }
    public var Checkout_PasswordEntry_Title: String { return self._s[985]! }
    public var Conversation_InputTextCaptionPlaceholder: String { return self._s[987]! }
    public var Common_Done: String { return self._s[988]! }
    public var Passport_Identity_FilesUploadNew: String { return self._s[989]! }
    public var PrivacySettings_LastSeenContacts: String { return self._s[991]! }
    public var Passport_Language_vi: String { return self._s[992]! }
    public var CheckoutInfo_ShippingInfoAddress1: String { return self._s[993]! }
    public var UserInfo_LastNamePlaceholder: String { return self._s[994]! }
    public var Conversation_StatusKickedFromChannel: String { return self._s[996]! }
    public var CheckoutInfo_ShippingInfoAddress2: String { return self._s[997]! }
    public func DialogList_SingleTypingSuffix(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[998]!, self._r[998]!, [_0])
    }
    public var LastSeen_JustNow: String { return self._s[999]! }
    public var GroupInfo_InviteLink_RevokeAlert_Text: String { return self._s[1000]! }
    public var BroadcastListInfo_AddRecipient: String { return self._s[1001]! }
    public func Channel_Management_ErrorNotMember(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1002]!, self._r[1002]!, [_0])
    }
    public var Privacy_Calls_NeverAllow: String { return self._s[1003]! }
    public var Settings_About_Title: String { return self._s[1004]! }
    public var PhoneNumberHelp_Help: String { return self._s[1005]! }
    public var Channel_LinkItem: String { return self._s[1007]! }
    public var Camera_Retake: String { return self._s[1008]! }
    public var StickerPack_ShowStickers: String { return self._s[1009]! }
    public var Conversation_RestrictedText: String { return self._s[1010]! }
    public var Channel_Stickers_YourStickers: String { return self._s[1011]! }
    public func CHAT_CREATED(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1015]!, self._r[1015]!, [_1, _2])
    }
    public var LastSeen_WithinAMonth: String { return self._s[1016]! }
    public func PrivacySettings_LastSeenContactsPlus(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1017]!, self._r[1017]!, [_0])
    }
    public var ApplyLanguage_UnsufficientDataTitle: String { return self._s[1018]! }
    public var ChangePhoneNumberNumber_NewNumber: String { return self._s[1020]! }
    public var Compose_NewChannel: String { return self._s[1021]! }
    public var NotificationsSound_Circles: String { return self._s[1022]! }
    public var Login_TermsOfServiceAgree: String { return self._s[1024]! }
    public var Channel_AdminLog_CanChangeInviteLink: String { return self._s[1025]! }
    public func Passport_RequestHeader(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1026]!, self._r[1026]!, [_0])
    }
    public func Call_CallInProgressMessage(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1027]!, self._r[1027]!, [_1, _2])
    }
    public var Conversation_InputTextBroadcastPlaceholder: String { return self._s[1029]! }
    public func ShareFileTip_Text(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1031]!, self._r[1031]!, [_0])
    }
    public func CancelResetAccount_TextSMS(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1032]!, self._r[1032]!, [_0])
    }
    public var Channel_EditAdmin_PermissionInviteUsers: String { return self._s[1033]! }
    public var Privacy_Calls_P2PNever: String { return self._s[1034]! }
    public var GroupInfo_DeleteAndExit: String { return self._s[1035]! }
    public var GroupInfo_InviteLink_CopyLink: String { return self._s[1036]! }
    public var Weekday_Friday: String { return self._s[1038]! }
    public var Login_ResetAccountProtected_Title: String { return self._s[1039]! }
    public var Settings_SetProfilePhoto: String { return self._s[1040]! }
    public var Compose_ChannelTokenListPlaceholder: String { return self._s[1041]! }
    public var Channel_EditAdmin_PermissionPinMessages: String { return self._s[1042]! }
    public var Your_card_has_expired: String { return self._s[1043]! }
    public func CHAT_MESSAGE_INVOICE(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1046]!, self._r[1046]!, [_1, _2, _3])
    }
    public var ChannelInfo_ConfirmLeave: String { return self._s[1047]! }
    public var ShareMenu_CopyShareLinkGame: String { return self._s[1048]! }
    public var ReportPeer_ReasonOther: String { return self._s[1050]! }
    public func Username_UsernameIsAvailable(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1051]!, self._r[1051]!, [_0])
    }
    public var KeyCommand_JumpToNextUnreadChat: String { return self._s[1053]! }
    public var InfoPlist_NSContactsUsageDescription: String { return self._s[1054]! }
    public func SocksProxySetup_ProxyStatusPing(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1056]!, self._r[1056]!, [_0])
    }
    public func Date_ChatDateHeader(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1057]!, self._r[1057]!, [_1, _2])
    }
    public var Conversation_EncryptedDescriptionTitle: String { return self._s[1059]! }
    public var DialogList_Pin: String { return self._s[1060]! }
    public func Notification_RemovedGroupPhoto(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1061]!, self._r[1061]!, [_0])
    }
    public var Channel_ErrorAddTooMuch: String { return self._s[1062]! }
    public var GroupInfo_SharedMediaNone: String { return self._s[1063]! }
    public var ChatSettings_TextSizeUnits: String { return self._s[1064]! }
    public var ChatSettings_AutoPlayAnimations: String { return self._s[1065]! }
    public var Conversation_FileOpenIn: String { return self._s[1066]! }
    public var Channel_Setup_TypePublic: String { return self._s[1067]! }
    public func ChangePhone_ErrorOccupied(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1068]!, self._r[1068]!, [_0])
    }
    public var ContactInfo_PhoneLabelMain: String { return self._s[1069]! }
    public var Clipboard_SendPhoto: String { return self._s[1070]! }
    public var Privacy_GroupsAndChannels_CustomShareHelp: String { return self._s[1071]! }
    public var KeyCommand_ChatInfo: String { return self._s[1072]! }
    public var Channel_AdminLog_EmptyFilterTitle: String { return self._s[1073]! }
    public var PhotoEditor_HighlightsTint: String { return self._s[1074]! }
    public var Passport_Address_Region: String { return self._s[1076]! }
    public var Watch_Compose_AddContact: String { return self._s[1077]! }
    public func Time_PreciseDate_m5(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1078]!, self._r[1078]!, [_1, _2, _3])
    }
    public func Channel_AdminLog_MessageKickedNameUsername(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1079]!, self._r[1079]!, [_1, _2])
    }
    public func Login_WillSendSms(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1080]!, self._r[1080]!, [_0])
    }
    public var Coub_TapForSound: String { return self._s[1081]! }
    public func AuthCode_Alert(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1083]!, self._r[1083]!, [_0])
    }
    public var Compose_NewEncryptedChat: String { return self._s[1085]! }
    public var PhotoEditor_CropReset: String { return self._s[1086]! }
    public var Privacy_Calls_P2PAlways: String { return self._s[1088]! }
    public var Passport_Address_TypeTemporaryRegistrationUploadScan: String { return self._s[1089]! }
    public var Login_InvalidLastNameError: String { return self._s[1090]! }
    public var Channel_Members_AddMembers: String { return self._s[1091]! }
    public var Tour_Title2: String { return self._s[1092]! }
    public var Login_TermsOfServiceHeader: String { return self._s[1094]! }
    public var Channel_AdminLog_BanSendGifs: String { return self._s[1095]! }
    public var Login_TermsOfServiceSignupDecline: String { return self._s[1097]! }
    public var InfoPlist_NSMicrophoneUsageDescription: String { return self._s[1098]! }
    public var AuthSessions_OtherSessions: String { return self._s[1099]! }
    public var Watch_UserInfo_Title: String { return self._s[1100]! }
    public var InstantPage_FeedbackButton: String { return self._s[1101]! }
    public func Generic_OpenHiddenLinkAlert(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1102]!, self._r[1102]!, [_0])
    }
    public var Conversation_Contact: String { return self._s[1103]! }
    public var NetworkUsageSettings_GeneralDataSection: String { return self._s[1104]! }
    public var EnterPasscode_RepeatNewPasscode: String { return self._s[1107]! }
    public var Conversation_ContextMenuCopyLink: String { return self._s[1108]! }
    public var Passport_Language_sk: String { return self._s[1109]! }
    public var InstantPage_AutoNightTheme: String { return self._s[1110]! }
    public var CloudStorage_Title: String { return self._s[1111]! }
    public var Month_ShortOctober: String { return self._s[1112]! }
    public var Settings_FAQ: String { return self._s[1114]! }
    public var PrivacySettings_LastSeen: String { return self._s[1115]! }
    public var DialogList_SearchSectionRecent: String { return self._s[1116]! }
    public var ChatSettings_AutomaticVideoMessageDownload: String { return self._s[1117]! }
    public var Conversation_ContextMenuDelete: String { return self._s[1118]! }
    public var Tour_Text6: String { return self._s[1119]! }
    public var PhotoEditor_WarmthTool: String { return self._s[1120]! }
    public var Passport_Address_TypePassportRegistrationUploadScan: String { return self._s[1122]! }
    public var Common_TakePhoto: String { return self._s[1123]! }
    public var SocksProxySetup_AdNoticeHelp: String { return self._s[1124]! }
    public var UserInfo_CreateNewContact: String { return self._s[1126]! }
    public var NetworkUsageSettings_MediaDocumentDataSection: String { return self._s[1127]! }
    public var Login_CodeSentCall: String { return self._s[1128]! }
    public var Watch_PhotoView_Title: String { return self._s[1129]! }
    public func PrivacySettings_LastSeenContactsMinus(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1130]!, self._r[1130]!, [_0])
    }
    public var ShareMenu_SelectChats: String { return self._s[1132]! }
    public var Group_ErrorSendRestrictedMedia: String { return self._s[1133]! }
    public var Group_Setup_HistoryVisible: String { return self._s[1134]! }
    public var Channel_EditAdmin_PermissinAddAdminOff: String { return self._s[1135]! }
    public var DialogList_ProxyConnectionIssuesTooltip: String { return self._s[1137]! }
    public var Cache_Files: String { return self._s[1138]! }
    public var PhotoEditor_EnhanceTool: String { return self._s[1140]! }
    public var Conversation_SearchPlaceholder: String { return self._s[1141]! }
    public var Channel_Stickers_NotFound: String { return self._s[1142]! }
    public var UserInfo_NotificationsDefaultEnabled: String { return self._s[1146]! }
    public var WatchRemote_AlertText: String { return self._s[1147]! }
    public var Channel_AdminLog_CanInviteUsers: String { return self._s[1149]! }
    public var Channel_BanUser_PermissionReadMessages: String { return self._s[1151]! }
    public var AttachmentMenu_PhotoOrVideo: String { return self._s[1152]! }
    public var Passport_Identity_GenderPlaceholder: String { return self._s[1153]! }
    public var Month_ShortMarch: String { return self._s[1154]! }
    public var GroupInfo_InviteLink_Title: String { return self._s[1155]! }
    public var Watch_LastSeen_JustNow: String { return self._s[1156]! }
    public var PhoneLabel_Title: String { return self._s[1157]! }
    public var PrivacySettings_Passcode: String { return self._s[1159]! }
    public var Paint_ClearConfirm: String { return self._s[1161]! }
    public var SocksProxySetup_Secret: String { return self._s[1162]! }
    public func Checkout_SavePasswordTimeout(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1163]!, self._r[1163]!, [_0])
    }
    public var PhotoEditor_BlurToolOff: String { return self._s[1164]! }
    public var AccessDenied_VideoMicrophone: String { return self._s[1165]! }
    public var Weekday_ShortThursday: String { return self._s[1166]! }
    public var UserInfo_ShareContact: String { return self._s[1167]! }
    public var LoginPassword_InvalidPasswordError: String { return self._s[1168]! }
    public var NotificationsSound_Calypso: String { return self._s[1170]! }
    public func MESSAGE_PHOTO_SECRET(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1171]!, self._r[1171]!, [_1])
    }
    public var Login_PhoneAndCountryHelp: String { return self._s[1172]! }
    public var CheckoutInfo_ReceiverInfoName: String { return self._s[1173]! }
    public var NotificationsSound_Popcorn: String { return self._s[1175]! }
    public func Time_YesterdayAt(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1176]!, self._r[1176]!, [_0])
    }
    public var Weekday_Yesterday: String { return self._s[1177]! }
    public var Conversation_InputTextSilentBroadcastPlaceholder: String { return self._s[1178]! }
    public var Embed_PlayingInPIP: String { return self._s[1179]! }
    public var Localization_EnglishLanguageName: String { return self._s[1180]! }
    public var Call_StatusIncoming: String { return self._s[1181]! }
    public var Settings_Appearance: String { return self._s[1182]! }
    public func ApplyLanguage_ChangeLanguageAlreadyActive(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1184]!, self._r[1184]!, [_1])
    }
    public var Settings_PrivacySettings: String { return self._s[1185]! }
    public var Conversation_SilentBroadcastTooltipOn: String { return self._s[1186]! }
    public func SecretVideo_NotViewedYet(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1187]!, self._r[1187]!, [_0])
    }
    public func CHAT_MESSAGE_GEO(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1188]!, self._r[1188]!, [_1, _2])
    }
    public var DialogList_SearchLabel: String { return self._s[1190]! }
    public var InfoPlist_NSLocationAlwaysAndWhenInUseUsageDescription: String { return self._s[1191]! }
    public var Login_CodeSentInternal: String { return self._s[1192]! }
    public var Channel_AdminLog_BanSendMessages: String { return self._s[1194]! }
    public var Channel_MessagePhotoRemoved: String { return self._s[1195]! }
    public var Conversation_StatusKickedFromGroup: String { return self._s[1196]! }
    public var GroupInfo_ChatAdmins: String { return self._s[1197]! }
    public var PhotoEditor_CurvesAll: String { return self._s[1198]! }
    public func Notification_LeftChannel(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1199]!, self._r[1199]!, [_0])
    }
    public var Compose_Create: String { return self._s[1200]! }
    public func Passport_Identity_NativeNameGenericHelp(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1201]!, self._r[1201]!, [_0])
    }
    public func LOCKED_MESSAGE(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1202]!, self._r[1202]!, [_1])
    }
    public var Conversation_ClearPrivateHistory: String { return self._s[1203]! }
    public var Conversation_ContextMenuShare: String { return self._s[1204]! }
    public var Notifications_ExceptionsNone: String { return self._s[1205]! }
    public func Time_MonthOfYear_m6(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1206]!, self._r[1206]!, [_0])
    }
    public var Conversation_ContextMenuReport: String { return self._s[1207]! }
    public func Call_GroupFormat(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1209]!, self._r[1209]!, [_1, _2])
    }
    public var Forward_ChannelReadOnly: String { return self._s[1210]! }
    public var Passport_InfoText: String { return self._s[1212]! }
    public var Privacy_GroupsAndChannels_NeverAllow_Title: String { return self._s[1213]! }
    public func Passport_Address_UploadOneOfScan(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1214]!, self._r[1214]!, [_0])
    }
    public var AutoDownloadSettings_Reset: String { return self._s[1215]! }
    public var NotificationsSound_Synth: String { return self._s[1216]! }
    public var TextFormat_Bold: String { return self._s[1217]! }
    public func Channel_AdminLog_MessageInvitedName(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1218]!, self._r[1218]!, [_1])
    }
    public var Conversation_Moderate_Ban: String { return self._s[1221]! }
    public var Group_Status: String { return self._s[1223]! }
    public var SocksProxySetup_ShareProxyList: String { return self._s[1226]! }
    public var Passport_Phone_Delete: String { return self._s[1227]! }
    public var Conversation_InputTextPlaceholder: String { return self._s[1228]! }
    public var ContactInfo_PhoneLabelOther: String { return self._s[1229]! }
    public var Passport_Language_lv: String { return self._s[1231]! }
    public var TwoStepAuth_RecoveryCode: String { return self._s[1232]! }
    public var Conversation_EditingMessageMediaEditCurrentPhoto: String { return self._s[1233]! }
    public var Passport_DeleteDocumentConfirmation: String { return self._s[1234]! }
    public var Passport_Language_hy: String { return self._s[1235]! }
    public var SharedMedia_CategoryDocs: String { return self._s[1238]! }
    public var Channel_AdminLog_CanChangeInfo: String { return self._s[1240]! }
    public var Channel_AdminLogFilter_EventsAdmins: String { return self._s[1241]! }
    public var Group_Setup_HistoryHiddenHelp: String { return self._s[1242]! }
    public func AuthSessions_AppUnofficial(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1243]!, self._r[1243]!, [_0])
    }
    public var NotificationsSound_Telegraph: String { return self._s[1244]! }
    public var AutoNightTheme_Disabled: String { return self._s[1245]! }
    public var Conversation_ContextMenuBan: String { return self._s[1246]! }
    public var Channel_EditAdmin_PermissionsHeader: String { return self._s[1247]! }
    public var SocksProxySetup_PortPlaceholder: String { return self._s[1248]! }
    public func DialogList_SingleUploadingVideoSuffix(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1250]!, self._r[1250]!, [_0])
    }
    public var Group_UpgradeNoticeHeader: String { return self._s[1251]! }
    public func CHAT_DELETE_YOU(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1252]!, self._r[1252]!, [_1, _2])
    }
    public func MESSAGE_NOTEXT(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1253]!, self._r[1253]!, [_1])
    }
    public func ApplyLanguage_ChangeLanguageUnofficialText(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1254]!, self._r[1254]!, [_1, _2])
    }
    public func CHAT_MESSAGE_GIF(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1256]!, self._r[1256]!, [_1, _2])
    }
    public var GroupInfo_InviteLink_CopyAlert_Success: String { return self._s[1257]! }
    public var Channel_Info_Members: String { return self._s[1258]! }
    public var ShareFileTip_CloseTip: String { return self._s[1259]! }
    public var KeyCommand_Find: String { return self._s[1260]! }
    public var SecretVideo_Title: String { return self._s[1261]! }
    public var Passport_DeleteAddressConfirmation: String { return self._s[1262]! }
    public var Passport_DiscardMessageAction: String { return self._s[1263]! }
    public var Passport_Language_dv: String { return self._s[1264]! }
    public var Checkout_NewCard_PostcodeTitle: String { return self._s[1265]! }
    public var Notifications_Badge_CountUnreadMessages_InfoOn: String { return self._s[1267]! }
    public func Channel_AdminLog_MessageRestricted(_ _0: String, _ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1268]!, self._r[1268]!, [_0, _1, _2])
    }
    public var SocksProxySetup_SecretPlaceholder: String { return self._s[1269]! }
    public var Channel_EditAdmin_PermissinAddAdminOn: String { return self._s[1270]! }
    public var WebSearch_GIFs: String { return self._s[1271]! }
    public var Privacy_ChatsTitle: String { return self._s[1272]! }
    public var Conversation_SavedMessages: String { return self._s[1273]! }
    public var TwoStepAuth_EnterPasswordTitle: String { return self._s[1274]! }
    public func CHANNEL_MESSAGE_GAME(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1275]!, self._r[1275]!, [_1, _2])
    }
    public var Channel_Subscribers_Title: String { return self._s[1276]! }
    public var AccessDenied_CallMicrophone: String { return self._s[1277]! }
    public var Conversation_DeleteMessagesForEveryone: String { return self._s[1278]! }
    public var AuthSessions_Terminate: String { return self._s[1279]! }
    public var UserInfo_TapToCall: String { return self._s[1280]! }
    public var Common_Edit: String { return self._s[1281]! }
    public var TwoStepAuth_AddHintDescription: String { return self._s[1283]! }
    public var Conversation_OpenFile: String { return self._s[1284]! }
    public var PrivacyPolicy_Decline: String { return self._s[1286]! }
    public var Passport_Identity_ResidenceCountryPlaceholder: String { return self._s[1287]! }
    public var Message_PinnedDocumentMessage: String { return self._s[1288]! }
    public var AuthSessions_LogOut: String { return self._s[1290]! }
    public var Settings_AppLanguage_Unofficial: String { return self._s[1292]! }
    public var AutoDownloadSettings_PrivateChats: String { return self._s[1293]! }
    public var Checkout_TotalPaidAmount: String { return self._s[1294]! }
    public var Conversation_UnsupportedMedia: String { return self._s[1295]! }
    public var Passport_InvalidPasswordError: String { return self._s[1296]! }
    public func Message_ForwardedMessage(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1298]!, self._r[1298]!, [_0])
    }
    public func Time_PreciseDate_m4(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1299]!, self._r[1299]!, [_1, _2, _3])
    }
    public var Checkout_NewCard_SaveInfoEnableHelp: String { return self._s[1300]! }
    public var Call_AudioRouteHide: String { return self._s[1301]! }
    public var CallSettings_OnMobile: String { return self._s[1303]! }
    public var Conversation_GifTooltip: String { return self._s[1304]! }
    public var Passport_Address_EditBankStatement: String { return self._s[1305]! }
    public var CheckoutInfo_ErrorCityInvalid: String { return self._s[1307]! }
    public func CHANNEL_MESSAGE_PHOTOS(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1308]!, self._r[1308]!, [_1, _2])
    }
    public var Profile_CreateEncryptedChatError: String { return self._s[1309]! }
    public var Map_LocationTitle: String { return self._s[1310]! }
    public var Call_RateCall: String { return self._s[1311]! }
    public var Login_CancelPhoneVerificationStop: String { return self._s[1312]! }
    public var Passport_Address_City: String { return self._s[1313]! }
    public var SocksProxySetup_PasswordPlaceholder: String { return self._s[1314]! }
    public var Message_ReplyActionButtonShowReceipt: String { return self._s[1316]! }
    public var PhotoEditor_ShadowsTool: String { return self._s[1317]! }
    public var Checkout_NewCard_CardholderNamePlaceholder: String { return self._s[1319]! }
    public var Cache_Title: String { return self._s[1321]! }
    public var Passport_Email_Title: String { return self._s[1322]! }
    public var Month_GenMay: String { return self._s[1323]! }
    public var PasscodeSettings_HelpBottom: String { return self._s[1324]! }
    public func Notification_CreatedChat(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1325]!, self._r[1325]!, [_0])
    }
    public var Calls_NoMissedCallsPlacehoder: String { return self._s[1326]! }
    public var Passport_Address_RegionPlaceholder: String { return self._s[1327]! }
    public var Channel_Stickers_NotFoundHelp: String { return self._s[1328]! }
    public var Watch_UserInfo_Block: String { return self._s[1329]! }
    public var Watch_LastSeen_ALongTimeAgo: String { return self._s[1330]! }
    public var StickerPacksSettings_ManagingHelp: String { return self._s[1331]! }
    public var Privacy_GroupsAndChannels_InviteToChannelMultipleError: String { return self._s[1332]! }
    public var SearchImages_Title: String { return self._s[1333]! }
    public var Channel_BlackList_Title: String { return self._s[1334]! }
    public func Conversation_LiveLocationYouAnd(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1336]!, self._r[1336]!, [_0])
    }
    public var TwoStepAuth_PasswordRemovePassportConfirmation: String { return self._s[1337]! }
    public var Checkout_NewCard_SaveInfo: String { return self._s[1338]! }
    public var Notification_CallMissed: String { return self._s[1339]! }
    public var Profile_ShareContactButton: String { return self._s[1340]! }
    public var Group_ErrorSendRestrictedStickers: String { return self._s[1341]! }
    public var Bot_GroupStatusDoesNotReadHistory: String { return self._s[1342]! }
    public var Notification_Mute1h: String { return self._s[1343]! }
    public func Channel_AdminLog_MessageUnkickedName(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1344]!, self._r[1344]!, [_1])
    }
    public var Settings_TabTitle: String { return self._s[1345]! }
    public var Passport_Identity_ExpiryDatePlaceholder: String { return self._s[1347]! }
    public var NetworkUsageSettings_MediaAudioDataSection: String { return self._s[1348]! }
    public var GroupInfo_DeactivatedStatus: String { return self._s[1349]! }
    public func CHAT_PHOTO_EDITED(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1350]!, self._r[1350]!, [_1, _2])
    }
    public var Conversation_ContextMenuMore: String { return self._s[1351]! }
    public func PrivacySettings_LastSeenEverybodyMinus(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1352]!, self._r[1352]!, [_0])
    }
    public var Map_ShareLiveLocation: String { return self._s[1353]! }
    public var Weekday_Today: String { return self._s[1354]! }
    public func PINNED_GEOLIVE(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1355]!, self._r[1355]!, [_1])
    }
    public func Conversation_RestrictedStickersTimed(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1356]!, self._r[1356]!, [_0])
    }
    public var Login_InvalidFirstNameError: String { return self._s[1357]! }
    public func Channel_AdminLog_MessageUnkickedNameUsername(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1358]!, self._r[1358]!, [_1, _2])
    }
    public func Notification_Joined(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1359]!, self._r[1359]!, [_0])
    }
    public func ApplyLanguage_UnsufficientDataText(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1360]!, self._r[1360]!, [_1])
    }
    public var Paint_Clear: String { return self._s[1361]! }
    public var TwoStepAuth_RecoveryFailed: String { return self._s[1363]! }
    public func MESSAGE_AUDIO(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1364]!, self._r[1364]!, [_1])
    }
    public var Checkout_PasswordEntry_Pay: String { return self._s[1365]! }
    public var Conversation_EditingMessagePanelMedia: String { return self._s[1366]! }
    public var Notifications_MessageNotificationsHelp: String { return self._s[1367]! }
    public var EnterPasscode_EnterCurrentPasscode: String { return self._s[1368]! }
    public var Conversation_EditingMessageMediaEditCurrentVideo: String { return self._s[1369]! }
    public func MESSAGE_GAME(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1370]!, self._r[1370]!, [_1, _2])
    }
    public var Conversation_Moderate_Report: String { return self._s[1371]! }
    public var MessageTimer_Forever: String { return self._s[1372]! }
    public var DialogList_SavedMessagesHelp: String { return self._s[1373]! }
    public func Conversation_EncryptedPlaceholderTitleIncoming(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1374]!, self._r[1374]!, [_0])
    }
    public func Map_AccurateTo(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1376]!, self._r[1376]!, [_0])
    }
    public func Call_ParticipantVersionOutdatedError(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1377]!, self._r[1377]!, [_0])
    }
    public var Passport_Identity_ReverseSideHelp: String { return self._s[1378]! }
    public var Tour_Text2: String { return self._s[1379]! }
    public var Call_StatusNoAnswer: String { return self._s[1381]! }
    public func Passport_Phone_UseTelegramNumber(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1382]!, self._r[1382]!, [_0])
    }
    public var Channel_AdminLogFilter_EventsLeavingSubscribers: String { return self._s[1383]! }
    public var Conversation_MessageDialogDelete: String { return self._s[1386]! }
    public var Appearance_PreviewOutgoingText: String { return self._s[1387]! }
    public var Login_CheckOtherSessionMessages: String { return self._s[1388]! }
    public var Username_Placeholder: String { return self._s[1389]! }
    public func Notification_PinnedDeletedMessage(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1390]!, self._r[1390]!, [_0])
    }
    public func Time_MonthOfYear_m11(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1391]!, self._r[1391]!, [_0])
    }
    public var TwoStepAuth_ReEnterPasswordTitle: String { return self._s[1392]! }
    public var UserInfo_BotHelp: String { return self._s[1393]! }
    public var TwoStepAuth_PasswordSet: String { return self._s[1394]! }
    public func CHANNEL_MESSAGE_VIDEO(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1395]!, self._r[1395]!, [_1])
    }
    public var EnterPasscode_TouchId: String { return self._s[1396]! }
    public var AuthSessions_LoggedInWithTelegram: String { return self._s[1397]! }
    public var Checkout_ErrorInvoiceAlreadyPaid: String { return self._s[1400]! }
    public var ChatAdmins_Title: String { return self._s[1401]! }
    public var ChannelMembers_WhoCanAddMembers: String { return self._s[1402]! }
    public var Passport_Language_ar: String { return self._s[1403]! }
    public var PasscodeSettings_Help: String { return self._s[1404]! }
    public var Conversation_EditingMessagePanelTitle: String { return self._s[1405]! }
    public var Settings_AboutEmpty: String { return self._s[1406]! }
    public func NetworkUsageSettings_CellularUsageSince(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1407]!, self._r[1407]!, [_0])
    }
    public var GroupInfo_ConvertToSupergroup: String { return self._s[1408]! }
    public func Notification_PinnedContactMessage(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1409]!, self._r[1409]!, [_0])
    }
    public var CallSettings_UseLessDataLongDescription: String { return self._s[1410]! }
    public var FastTwoStepSetup_PasswordPlaceholder: String { return self._s[1411]! }
    public var Conversation_SecretChatContextBotAlert: String { return self._s[1412]! }
    public var Channel_Moderator_AccessLevelRevoke: String { return self._s[1413]! }
    public var CheckoutInfo_ReceiverInfoTitle: String { return self._s[1414]! }
    public var Channel_AdminLogFilter_EventsRestrictions: String { return self._s[1415]! }
    public var GroupInfo_InviteLink_RevokeLink: String { return self._s[1417]! }
    public var Checkout_PaymentMethod_Title: String { return self._s[1418]! }
    public var Conversation_Unmute: String { return self._s[1419]! }
    public var AutoDownloadSettings_DocumentsTitle: String { return self._s[1420]! }
    public var Passport_FieldOneOf_FinalDelimeter: String { return self._s[1422]! }
    public var Notifications_MessageNotifications: String { return self._s[1423]! }
    public var Passport_ForgottenPassword: String { return self._s[1425]! }
    public var ChannelMembers_WhoCanAddMembersAdminsHelp: String { return self._s[1426]! }
    public var DialogList_DeleteBotConversationConfirmation: String { return self._s[1427]! }
    public var Passport_Identity_TranslationHelp: String { return self._s[1428]! }
    public func Update_AppVersion(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1429]!, self._r[1429]!, [_0])
    }
    public func DialogList_MultipleTyping(_ _0: String, _ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1430]!, self._r[1430]!, [_0, _1])
    }
    public var Passport_Identity_OneOfTypeIdentityCard: String { return self._s[1431]! }
    public var Conversation_ClousStorageInfo_Description2: String { return self._s[1432]! }
    public func Time_MonthOfYear_m5(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1433]!, self._r[1433]!, [_0])
    }
    public var Map_Hybrid: String { return self._s[1434]! }
    public var Channel_Setup_Title: String { return self._s[1435]! }
    public var MediaPicker_TimerTooltip: String { return self._s[1436]! }
    public var Activity_UploadingVideo: String { return self._s[1437]! }
    public var Channel_Info_Management: String { return self._s[1438]! }
    public func Login_TermsOfService_ProceedBot(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1439]!, self._r[1439]!, [_0])
    }
    public var TwoStepAuth_ConfirmEmailCodePlaceholder: String { return self._s[1440]! }
    public func Notification_MessageLifetimeChangedOutgoing(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1441]!, self._r[1441]!, [_1])
    }
    public var PhotoEditor_QualityVeryLow: String { return self._s[1442]! }
    public var Stickers_AddToFavorites: String { return self._s[1443]! }
    public var Month_ShortFebruary: String { return self._s[1444]! }
    public var Notifications_AddExceptionTitle: String { return self._s[1445]! }
    public var Conversation_ForwardTitle: String { return self._s[1446]! }
    public var Settings_FAQ_URL: String { return self._s[1447]! }
    public var Activity_RecordingVideoMessage: String { return self._s[1448]! }
    public var SharedMedia_EmptyFilesText: String { return self._s[1449]! }
    public func Contacts_AccessDeniedHelpLandscape(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1450]!, self._r[1450]!, [_0])
    }
    public var PasscodeSettings_UnlockWithTouchId: String { return self._s[1451]! }
    public var Contacts_AccessDeniedHelpON: String { return self._s[1452]! }
    public var Passport_Identity_AddInternalPassport: String { return self._s[1453]! }
    public var NetworkUsageSettings_ResetStats: String { return self._s[1454]! }
    public var Share_AuthDescription: String { return self._s[1455]! }
    public func CHAT_MESSAGE_PHOTOS(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1456]!, self._r[1456]!, [_1, _2, _3])
    }
    public func PrivacySettings_LastSeenContactsMinusPlus(_ _0: String, _ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1457]!, self._r[1457]!, [_0, _1])
    }
    public var Channel_AdminLog_EmptyMessageText: String { return self._s[1458]! }
    public func Notification_ChannelInviter(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1459]!, self._r[1459]!, [_0])
    }
    public var SocksProxySetup_TypeSocks: String { return self._s[1460]! }
    public var Profile_MessageLifetimeForever: String { return self._s[1461]! }
    public var MediaPicker_UngroupDescription: String { return self._s[1462]! }
    public func Checkout_SavePasswordTimeoutAndFaceId(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1463]!, self._r[1463]!, [_0])
    }
    public var SocksProxySetup_Username: String { return self._s[1464]! }
    public var Conversation_Edit: String { return self._s[1465]! }
    public var TwoStepAuth_ResetAccountHelp: String { return self._s[1466]! }
    public var Month_GenDecember: String { return self._s[1467]! }
    public func Watch_LastSeen_YesterdayAt(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1469]!, self._r[1469]!, [_0])
    }
    public var Channel_ErrorAddBlocked: String { return self._s[1470]! }
    public var Conversation_Unpin: String { return self._s[1471]! }
    public var Call_RecordingDisabledMessage: String { return self._s[1473]! }
    public var Passport_Address_TypeUtilityBill: String { return self._s[1474]! }
    public var Conversation_UnblockUser: String { return self._s[1475]! }
    public var Conversation_Unblock: String { return self._s[1476]! }
    public func CHANNEL_MESSAGE_GIF(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1477]!, self._r[1477]!, [_1])
    }
    public var Channel_AdminLogFilter_EventsEditedMessages: String { return self._s[1480]! }
    public var AutoNightTheme_ScheduleSection: String { return self._s[1481]! }
    public var Appearance_ThemeNightBlue: String { return self._s[1482]! }
    public func Passport_Scans_ScanIndex(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1483]!, self._r[1483]!, [_0])
    }
    public var Channel_Username_InvalidTooShort: String { return self._s[1484]! }
    public var Conversation_ViewGroup: String { return self._s[1485]! }
    public var Watch_LastSeen_WithinAWeek: String { return self._s[1486]! }
    public var BlockedUsers_SelectUserTitle: String { return self._s[1487]! }
    public var Profile_MessageLifetime1w: String { return self._s[1488]! }
    public var Passport_Address_TypeRentalAgreementUploadScan: String { return self._s[1491]! }
    public var DialogList_TabTitle: String { return self._s[1492]! }
    public var UserInfo_GenericPhoneLabel: String { return self._s[1493]! }
    public func Channel_AdminLog_MessagePromotedName(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1494]!, self._r[1494]!, [_1])
    }
    public var Group_Members_AddMemberBotErrorNotAllowed: String { return self._s[1495]! }
    public func Username_LinkHint(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1496]!, self._r[1496]!, [_0])
    }
    public var Map_StopLiveLocation: String { return self._s[1497]! }
    public var Message_LiveLocation: String { return self._s[1498]! }
    public var NetworkUsageSettings_Title: String { return self._s[1500]! }
    public var CheckoutInfo_ShippingInfoPostcodePlaceholder: String { return self._s[1501]! }
    public var InfoPlist_NSPhotoLibraryUsageDescription: String { return self._s[1502]! }
    public var Wallpaper_Wallpaper: String { return self._s[1503]! }
    public var GroupInfo_InviteLink_RevokeAlert_Revoke: String { return self._s[1504]! }
    public var SharedMedia_TitleLink: String { return self._s[1506]! }
    public func Channel_AdminLog_MessageRestrictedName(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1508]!, self._r[1508]!, [_1])
    }
    public func Channel_AdminLog_MessageGroupPreHistoryHidden(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1509]!, self._r[1509]!, [_0])
    }
    public var Channel_JoinChannel: String { return self._s[1510]! }
    public var StickerPack_Add: String { return self._s[1511]! }
    public var Group_ErrorNotMutualContact: String { return self._s[1513]! }
    public var AccessDenied_LocationDisabled: String { return self._s[1516]! }
    public var Login_UnknownError: String { return self._s[1517]! }
    public var Presence_online: String { return self._s[1518]! }
    public var DialogList_Title: String { return self._s[1520]! }
    public var Stickers_Install: String { return self._s[1523]! }
    public var SearchImages_NoImagesFound: String { return self._s[1526]! }
    public func Watch_Time_ShortTodayAt(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1528]!, self._r[1528]!, [_0])
    }
    public var Channel_AdminLogFilter_EventsNewSubscribers: String { return self._s[1529]! }
    public var Passport_Identity_ExpiryDate: String { return self._s[1530]! }
    public var UserInfo_GroupsInCommon: String { return self._s[1531]! }
    public var Message_PinnedContactMessage: String { return self._s[1532]! }
    public var AccessDenied_CameraDisabled: String { return self._s[1533]! }
    public func Time_PreciseDate_m3(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1534]!, self._r[1534]!, [_1, _2, _3])
    }
    public var Passport_Email_EnterOtherEmail: String { return self._s[1535]! }
    public func LiveLocationUpdated_YesterdayAt(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1536]!, self._r[1536]!, [_0])
    }
    public var NotificationsSound_Note: String { return self._s[1538]! }
    public var Passport_Identity_MiddleNamePlaceholder: String { return self._s[1540]! }
    public var PrivacyPolicy_Title: String { return self._s[1543]! }
    public var Month_GenMarch: String { return self._s[1544]! }
    public var Watch_UserInfo_Unmute: String { return self._s[1545]! }
    public var CheckoutInfo_ErrorPostcodeInvalid: String { return self._s[1546]! }
    public var Common_Delete: String { return self._s[1547]! }
    public var Username_Title: String { return self._s[1548]! }
    public var Login_PhoneFloodError: String { return self._s[1549]! }
    public var Channel_AdminLog_InfoPanelTitle: String { return self._s[1550]! }
    public func CHANNEL_MESSAGE_PHOTO(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1551]!, self._r[1551]!, [_1])
    }
    public func Channel_AdminLog_MessageToggleInvitesOff(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1552]!, self._r[1552]!, [_0])
    }
    public var Group_ErrorAddTooMuchBots: String { return self._s[1553]! }
    public func Notification_CallFormat(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1554]!, self._r[1554]!, [_1, _2])
    }
    public func CHAT_MESSAGE_PHOTO(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1555]!, self._r[1555]!, [_1, _2])
    }
    public func UserInfo_UnblockConfirmation(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1557]!, self._r[1557]!, [_0])
    }
    public var Appearance_PickAccentColor: String { return self._s[1558]! }
    public var Passport_Identity_EditDriversLicense: String { return self._s[1559]! }
    public var Passport_Identity_AddPassport: String { return self._s[1560]! }
    public var UserInfo_ShareBot: String { return self._s[1561]! }
    public var Settings_ProxyConnected: String { return self._s[1562]! }
    public var TwoStepAuth_RecoveryEmailAddDescription: String { return self._s[1563]! }
    public var ChatSettings_AutoDownloadVoiceMessages: String { return self._s[1564]! }
    public var TwoStepAuth_EmailSkip: String { return self._s[1566]! }
    public var Conversation_ViewContactDetails: String { return self._s[1567]! }
    public var Notifications_Badge_CountUnreadMessages_InfoOff: String { return self._s[1568]! }
    public var Conversation_JumpToDate: String { return self._s[1569]! }
    public var AutoDownloadSettings_VideoMessagesTitle: String { return self._s[1570]! }
    public var Passport_Address_OneOfTypeUtilityBill: String { return self._s[1572]! }
    public var CheckoutInfo_ReceiverInfoEmailPlaceholder: String { return self._s[1573]! }
    public var Message_Photo: String { return self._s[1575]! }
    public var Conversation_ReportSpam: String { return self._s[1576]! }
    public var Camera_FlashAuto: String { return self._s[1577]! }
    public var Passport_Identity_TypePassportUploadScan: String { return self._s[1579]! }
    public var Call_ConnectionErrorMessage: String { return self._s[1580]! }
    public var Stickers_FrequentlyUsed: String { return self._s[1581]! }
    public var LastSeen_ALongTimeAgo: String { return self._s[1583]! }
    public var Passport_Identity_ReverseSide: String { return self._s[1584]! }
    public var DialogList_SearchSectionGlobal: String { return self._s[1585]! }
    public var ChangePhoneNumberNumber_NumberPlaceholder: String { return self._s[1586]! }
    public var GroupInfo_AddUserLeftError: String { return self._s[1587]! }
    public var Appearance_ThemeDay: String { return self._s[1588]! }
    public var GroupInfo_GroupType: String { return self._s[1589]! }
    public var Watch_Suggestion_OnMyWay: String { return self._s[1590]! }
    public var Checkout_NewCard_PaymentCard: String { return self._s[1591]! }
    public func DialogList_SearchSubtitleFormat(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1592]!, self._r[1592]!, [_1, _2])
    }
    public var PhotoEditor_CropAspectRatioOriginal: String { return self._s[1593]! }
    public func Conversation_RestrictedInlineTimed(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1594]!, self._r[1594]!, [_0])
    }
    public var UserInfo_NotificationsDisabled: String { return self._s[1595]! }
    public func CONTACT_JOINED(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1596]!, self._r[1596]!, [_1])
    }
    public var NotificationsSound_Bamboo: String { return self._s[1598]! }
    public var PrivacyLastSeenSettings_AlwaysShareWith_Title: String { return self._s[1599]! }
    public func Channel_AdminLog_MessageGroupPreHistoryVisible(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1600]!, self._r[1600]!, [_0])
    }
    public var BlockedUsers_LeavePrefix: String { return self._s[1602]! }
    public var NetworkUsageSettings_ResetStatsConfirmation: String { return self._s[1603]! }
    public var Group_Setup_HistoryHeader: String { return self._s[1604]! }
    public var Channel_EditAdmin_PermissionPostMessages: String { return self._s[1607]! }
    public func Contacts_AddPhoneNumber(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1608]!, self._r[1608]!, [_0])
    }
    public func MESSAGE_SCREENSHOT(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1609]!, self._r[1609]!, [_1])
    }
    public var DialogList_EncryptionProcessing: String { return self._s[1610]! }
    public var GroupInfo_GroupHistory: String { return self._s[1612]! }
    public var Conversation_ApplyLocalization: String { return self._s[1613]! }
    public var FastTwoStepSetup_Title: String { return self._s[1614]! }
    public var SocksProxySetup_ProxyStatusUnavailable: String { return self._s[1615]! }
    public var Passport_Address_EditRentalAgreement: String { return self._s[1616]! }
    public var Conversation_DeleteManyMessages: String { return self._s[1618]! }
    public var CancelResetAccount_Title: String { return self._s[1619]! }
    public var Notification_CallOutgoingShort: String { return self._s[1620]! }
    public var SharedMedia_TitleAll: String { return self._s[1622]! }
    public var Conversation_SlideToCancel: String { return self._s[1623]! }
    public var AuthSessions_TerminateSession: String { return self._s[1624]! }
    public var Channel_AdminLogFilter_EventsDeletedMessages: String { return self._s[1625]! }
    public var PrivacyLastSeenSettings_AlwaysShareWith_Placeholder: String { return self._s[1626]! }
    public var Channel_Members_Title: String { return self._s[1627]! }
    public var Channel_AdminLog_CanDeleteMessages: String { return self._s[1628]! }
    public var Privacy_DeleteDrafts: String { return self._s[1629]! }
    public var Group_Setup_TypePrivateHelp: String { return self._s[1630]! }
    public func Notification_PinnedVideoMessage(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1631]!, self._r[1631]!, [_0])
    }
    public var Conversation_ContextMenuStickerPackAdd: String { return self._s[1632]! }
    public var Channel_AdminLogFilter_EventsNewMembers: String { return self._s[1633]! }
    public var Channel_AdminLogFilter_EventsPinned: String { return self._s[1635]! }
    public func Conversation_Moderate_DeleteAllMessages(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1637]!, self._r[1637]!, [_0])
    }
    public var SharedMedia_CategoryOther: String { return self._s[1638]! }
    public var Passport_Address_Address: String { return self._s[1639]! }
    public var DialogList_SavedMessagesTooltip: String { return self._s[1640]! }
    public var Preview_DeletePhoto: String { return self._s[1643]! }
    public var GroupInfo_ChannelListNamePlaceholder: String { return self._s[1644]! }
    public var PasscodeSettings_TurnPasscodeOn: String { return self._s[1645]! }
    public var AuthSessions_LogOutApplicationsHelp: String { return self._s[1646]! }
    public var Passport_FieldOneOf_Delimeter: String { return self._s[1648]! }
    public func Channel_AdminLog_MessageChangedGroupStickerPack(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1649]!, self._r[1649]!, [_0])
    }
    public var DialogList_Unpin: String { return self._s[1650]! }
    public var GroupInfo_SetGroupPhoto: String { return self._s[1652]! }
    public var StickerPacksSettings_ArchivedPacks_Info: String { return self._s[1653]! }
    public var ConvertToSupergroup_Title: String { return self._s[1655]! }
    public func CHAT_MESSAGE_NOTEXT(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1656]!, self._r[1656]!, [_1, _2])
    }
    public var Notification_CallCanceledShort: String { return self._s[1657]! }
    public var Channel_Setup_TypeHeader: String { return self._s[1658]! }
    public func Notification_NewAuthDetected(_ _1: String, _ _2: String, _ _3: String, _ _4: String, _ _5: String, _ _6: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1659]!, self._r[1659]!, [_1, _2, _3, _4, _5, _6])
    }
    public func Channel_AdminLog_MessageRemovedGroupStickerPack(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1660]!, self._r[1660]!, [_0])
    }
    public var PrivacyPolicy_DeclineTitle: String { return self._s[1663]! }
    public var AccessDenied_VideoMessageCamera: String { return self._s[1664]! }
    public var Privacy_ContactsSyncHelp: String { return self._s[1665]! }
    public var Conversation_Search: String { return self._s[1667]! }
    public func Channel_Management_PromotedBy(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1668]!, self._r[1668]!, [_0])
    }
    public func PrivacySettings_LastSeenNobodyPlus(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1669]!, self._r[1669]!, [_0])
    }
    public func Time_MonthOfYear_m4(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1670]!, self._r[1670]!, [_0])
    }
    public var SecretImage_Title: String { return self._s[1671]! }
    public var Notifications_InAppNotificationsSounds: String { return self._s[1672]! }
    public var Call_StatusRequesting: String { return self._s[1673]! }
    public func Channel_AdminLog_MessageRestrictedUntil(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1674]!, self._r[1674]!, [_0])
    }
    public func CHAT_MESSAGE_CONTACT(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1675]!, self._r[1675]!, [_1, _2])
    }
    public var SocksProxySetup_UseProxy: String { return self._s[1676]! }
    public var Group_UpgradeNoticeText1: String { return self._s[1677]! }
    public var ChatSettings_Other: String { return self._s[1678]! }
    public func Channel_AdminLog_MessageChangedChannelAbout(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1679]!, self._r[1679]!, [_0])
    }
    public var Channel_Stickers_CreateYourOwn: String { return self._s[1680]! }
    public func Call_EmojiDescription(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1682]!, self._r[1682]!, [_0])
    }
    public var Settings_SaveIncomingPhotos: String { return self._s[1683]! }
    public var TwoStepAuth_EnterEmailCode: String { return self._s[1684]! }
    public func Conversation_Bytes(_ _0: Int) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1685]!, self._r[1685]!, ["\(_0)"])
    }
    public var GroupInfo_InviteLink_Help: String { return self._s[1686]! }
    public var Calls_Missed: String { return self._s[1687]! }
    public var Conversation_ContextMenuForward: String { return self._s[1690]! }
    public var AutoDownloadSettings_ResetHelp: String { return self._s[1691]! }
    public var Passport_Identity_NativeNameHelp: String { return self._s[1692]! }
    public var Call_StatusRinging: String { return self._s[1693]! }
    public var Passport_Language_pl: String { return self._s[1694]! }
    public var Invitation_JoinGroup: String { return self._s[1695]! }
    public var Notification_PinnedMessage: String { return self._s[1696]! }
    public var AutoDownloadSettings_WiFi: String { return self._s[1698]! }
    public var Conversation_ClearSelfHistory: String { return self._s[1699]! }
    public var Message_Location: String { return self._s[1700]! }
    public func Notification_MessageLifetimeChanged(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1701]!, self._r[1701]!, [_1, _2])
    }
    public var Message_Contact: String { return self._s[1702]! }
    public var Passport_Language_lo: String { return self._s[1704]! }
    public var UserInfo_BotPrivacy: String { return self._s[1705]! }
    public var PasscodeSettings_AutoLock_IfAwayFor_1minute: String { return self._s[1706]! }
    public var Common_More: String { return self._s[1709]! }
    public var Preview_OpenInInstagram: String { return self._s[1710]! }
    public var PhotoEditor_HighlightsTool: String { return self._s[1713]! }
    public func Channel_Username_UsernameIsAvailable(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1714]!, self._r[1714]!, [_0])
    }
    public func PINNED_GAME(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1715]!, self._r[1715]!, [_1])
    }
    public var Invite_LargeRecipientsCountWarning: String { return self._s[1716]! }
    public var Passport_Language_hr: String { return self._s[1717]! }
    public var GroupInfo_BroadcastListNamePlaceholder: String { return self._s[1718]! }
    public var Activity_UploadingVideoMessage: String { return self._s[1719]! }
    public var Conversation_ShareBotContactConfirmation: String { return self._s[1720]! }
    public var Login_CodeSentSms: String { return self._s[1723]! }
    public func CHANNEL_MESSAGES(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1724]!, self._r[1724]!, [_1, _2])
    }
    public var Conversation_ReportSpamConfirmation: String { return self._s[1725]! }
    public var ChannelMembers_ChannelAdminsTitle: String { return self._s[1726]! }
    public var SocksProxySetup_Credentials: String { return self._s[1727]! }
    public var CallSettings_UseLessData: String { return self._s[1728]! }
    public var MediaPicker_GroupDescription: String { return self._s[1729]! }
    public var Conversation_SendMessageErrorGroupRestricted: String { return self._s[1730]! }
    public func TwoStepAuth_EnterPasswordHint(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1731]!, self._r[1731]!, [_0])
    }
    public var CallSettings_TabIcon: String { return self._s[1732]! }
    public var ConversationProfile_UnknownAddMemberError: String { return self._s[1734]! }
    public func Conversation_FileHowToText(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1737]!, self._r[1737]!, [_0])
    }
    public var Channel_AdminLog_BanSendMedia: String { return self._s[1738]! }
    public var Passport_Language_uz: String { return self._s[1739]! }
    public var Watch_UserInfo_Unblock: String { return self._s[1740]! }
    public var ChatSettings_AutoDownloadVideoMessages: String { return self._s[1742]! }
    public var PrivacyPolicy_AgeVerificationTitle: String { return self._s[1743]! }
    public var StickerPacksSettings_ArchivedMasks: String { return self._s[1745]! }
    public var Message_Animation: String { return self._s[1747]! }
    public var Checkout_PaymentMethod: String { return self._s[1748]! }
    public var Channel_AdminLog_TitleSelectedEvents: String { return self._s[1749]! }
    public var PrivacyPolicy_DeclineDeleteNow: String { return self._s[1750]! }
    public var Privacy_Calls_NeverAllow_Title: String { return self._s[1751]! }
    public var Cache_Music: String { return self._s[1752]! }
    public var Settings_ProxyDisabled: String { return self._s[1756]! }
    public var SocksProxySetup_Connecting: String { return self._s[1757]! }
    public var Channel_Username_CreatePrivateLinkHelp: String { return self._s[1758]! }
    public func Time_PreciseDate_m2(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1759]!, self._r[1759]!, [_1, _2, _3])
    }
    public func FileSize_B(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1761]!, self._r[1761]!, [_0])
    }
    public func Target_ShareGameConfirmationGroup(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1764]!, self._r[1764]!, [_0])
    }
    public var PhotoEditor_SaturationTool: String { return self._s[1766]! }
    public var Channel_BanUser_BlockFor: String { return self._s[1767]! }
    public var Call_StatusConnecting: String { return self._s[1768]! }
    public var AutoNightTheme_NotAvailable: String { return self._s[1769]! }
    public var PrivateDataSettings_Title: String { return self._s[1770]! }
    public var Bot_Start: String { return self._s[1772]! }
    public func Channel_AdminLog_MessageChangedGroupAbout(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1773]!, self._r[1773]!, [_0])
    }
    public var Appearance_PreviewReplyAuthor: String { return self._s[1774]! }
    public var Notifications_TextTone: String { return self._s[1775]! }
    public var Settings_CallSettings: String { return self._s[1776]! }
    public func Watch_Time_ShortYesterdayAt(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1777]!, self._r[1777]!, [_0])
    }
    public var Contacts_InviteToTelegram: String { return self._s[1778]! }
    public func PINNED_DOC(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1779]!, self._r[1779]!, [_1])
    }
    public var ChatSettings_PrivateChats: String { return self._s[1780]! }
    public var DialogList_Draft: String { return self._s[1781]! }
    public var Channel_EditAdmin_PermissionDeleteMessages: String { return self._s[1782]! }
    public var Channel_BanUser_PermissionSendStickersAndGifs: String { return self._s[1783]! }
    public var Conversation_CloudStorageInfo_Title: String { return self._s[1784]! }
    public var Conversation_ClearSecretHistory: String { return self._s[1785]! }
    public var Passport_Identity_EditIdentityCard: String { return self._s[1786]! }
    public var Notification_RenamedChannel: String { return self._s[1787]! }
    public var BlockedUsers_BlockUser: String { return self._s[1788]! }
    public var ChatSettings_TextSize: String { return self._s[1789]! }
    public var ChannelInfo_DeleteGroup: String { return self._s[1790]! }
    public var PhoneNumberHelp_Alert: String { return self._s[1791]! }
    public func PINNED_TEXT(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1792]!, self._r[1792]!, [_1, _2])
    }
    public var Watch_ChannelInfo_Title: String { return self._s[1793]! }
    public var WebSearch_RecentSectionClear: String { return self._s[1794]! }
    public var Channel_AdminLogFilter_AdminsAll: String { return self._s[1795]! }
    public var Channel_Setup_TypePrivate: String { return self._s[1796]! }
    public var PhotoEditor_TintTool: String { return self._s[1797]! }
    public var Watch_Suggestion_CantTalk: String { return self._s[1798]! }
    public var PhotoEditor_QualityHigh: String { return self._s[1799]! }
    public var SocksProxySetup_AddProxyTitle: String { return self._s[1801]! }
    public func CHAT_MESSAGE_STICKER(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1803]!, self._r[1803]!, [_1, _2, _3])
    }
    public var Map_ChooseAPlace: String { return self._s[1804]! }
    public var Passport_Identity_NamePlaceholder: String { return self._s[1806]! }
    public var Passport_ScanPassport: String { return self._s[1807]! }
    public var ApplyLanguage_ChangeLanguageTitle: String { return self._s[1808]! }
    public var Map_ShareLiveLocationHelp: String { return self._s[1809]! }
    public var Watch_Bot_Restart: String { return self._s[1811]! }
    public var Passport_RequestedInformation: String { return self._s[1812]! }
    public var Channel_About_Help: String { return self._s[1813]! }
    public var Web_OpenExternal: String { return self._s[1814]! }
    public var Passport_Language_mn: String { return self._s[1815]! }
    public var UserInfo_AddContact: String { return self._s[1817]! }
    public var Privacy_ContactsSync: String { return self._s[1818]! }
    public var SocksProxySetup_Connection: String { return self._s[1820]! }
    public var Passport_NotLoggedInMessage: String { return self._s[1821]! }
    public var Passport_PasswordPlaceholder: String { return self._s[1822]! }
    public var Passport_PasswordCreate: String { return self._s[1823]! }
    public var SocksProxySetup_ProxyStatusChecking: String { return self._s[1825]! }
    public var Call_EncryptionKey_Title: String { return self._s[1826]! }
    public var PhotoEditor_BlurToolLinear: String { return self._s[1828]! }
    public var AuthSessions_EmptyText: String { return self._s[1829]! }
    public var Notification_MessageLifetime1m: String { return self._s[1830]! }
    public func Call_StatusBar(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1831]!, self._r[1831]!, [_0])
    }
    public var EditProfile_NameAndPhotoHelp: String { return self._s[1832]! }
    public var NotificationsSound_Tritone: String { return self._s[1833]! }
    public var Passport_FieldAddressUploadHelp: String { return self._s[1834]! }
    public var Month_ShortJuly: String { return self._s[1835]! }
    public var CheckoutInfo_ShippingInfoAddress1Placeholder: String { return self._s[1836]! }
    public var Watch_MessageView_ViewOnPhone: String { return self._s[1837]! }
    public var CallSettings_Never: String { return self._s[1838]! }
    public var Passport_Identity_TypeInternalPassportUploadScan: String { return self._s[1841]! }
    public var TwoStepAuth_EmailSent: String { return self._s[1842]! }
    public func Notification_PinnedAnimationMessage(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1843]!, self._r[1843]!, [_0])
    }
    public var TwoStepAuth_RecoveryTitle: String { return self._s[1846]! }
    public var Notifications_MessageNotificationsExceptions: String { return self._s[1847]! }
    public var WatchRemote_AlertOpen: String { return self._s[1849]! }
    public var ExplicitContent_AlertChannel: String { return self._s[1850]! }
    public var Notification_PassportValueEmail: String { return self._s[1851]! }
    public var ContactInfo_PhoneLabelMobile: String { return self._s[1853]! }
    public var Widget_AuthRequired: String { return self._s[1855]! }
    public func ForwardedAuthors2(_ _0: String, _ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1856]!, self._r[1856]!, [_0, _1])
    }
    public var ChannelInfo_DeleteGroupConfirmation: String { return self._s[1857]! }
    public var TwoStepAuth_ConfirmationText: String { return self._s[1858]! }
    public var Login_SmsRequestState3: String { return self._s[1859]! }
    public var Notifications_AlertTones: String { return self._s[1860]! }
    public func Time_MonthOfYear_m10(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1861]!, self._r[1861]!, [_0])
    }
    public var Login_InfoAvatarPhoto: String { return self._s[1863]! }
    public var Calls_TabTitle: String { return self._s[1866]! }
    public var Map_YouAreHere: String { return self._s[1867]! }
    public var PhotoEditor_CurvesTool: String { return self._s[1868]! }
    public var Map_LiveLocationFor1Hour: String { return self._s[1869]! }
    public var AutoNightTheme_AutomaticSection: String { return self._s[1870]! }
    public var Stickers_NoStickersFound: String { return self._s[1871]! }
    public var Passport_Identity_AddIdentityCard: String { return self._s[1873]! }
    public func Notification_JoinedChannel(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1874]!, self._r[1874]!, [_0])
    }
    public var Passport_Language_et: String { return self._s[1875]! }
    public var Passport_Language_en: String { return self._s[1876]! }
    public var Login_CancelPhoneVerification: String { return self._s[1877]! }
    public var GroupInfo_ActionRestrict: String { return self._s[1880]! }
    public var Checkout_ShippingOption_Title: String { return self._s[1881]! }
    public var Stickers_SuggestStickers: String { return self._s[1883]! }
    public func Channel_AdminLog_MessageKickedName(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1887]!, self._r[1887]!, [_1])
    }
    public var Conversation_EncryptionProcessing: String { return self._s[1888]! }
    public var TwoStepAuth_EmailCodeExpired: String { return self._s[1889]! }
    public func CHAT_ADD_MEMBER(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1892]!, self._r[1892]!, [_1, _2, _3])
    }
    public var Weekday_ShortSunday: String { return self._s[1895]! }
    public var Privacy_ContactsResetConfirmation: String { return self._s[1896]! }
    public var Month_ShortJune: String { return self._s[1897]! }
    public var Privacy_Calls_Integration: String { return self._s[1898]! }
    public var Channel_TypeSetup_Title: String { return self._s[1899]! }
    public var Month_GenApril: String { return self._s[1900]! }
    public var StickerPacksSettings_ShowStickersButton: String { return self._s[1901]! }
    public var CheckoutInfo_ShippingInfoTitle: String { return self._s[1902]! }
    public var Notification_PassportValueProofOfAddress: String { return self._s[1903]! }
    public var Weekday_Tuesday: String { return self._s[1904]! }
    public var StickerPacksSettings_ShowStickersButtonHelp: String { return self._s[1905]! }
    public func Compatibility_SecretMediaVersionTooLow(_ _0: String, _ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1906]!, self._r[1906]!, [_0, _1])
    }
    public var CallSettings_RecentCalls: String { return self._s[1907]! }
    public func Conversation_Megabytes(_ _0: Float) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1912]!, self._r[1912]!, ["\(_0)"])
    }
    public var Conversation_SearchByName_Prefix: String { return self._s[1915]! }
    public var TwoStepAuth_FloodError: String { return self._s[1916]! }
    public var Paint_Stickers: String { return self._s[1917]! }
    public var Login_InvalidCountryCode: String { return self._s[1918]! }
    public var Privacy_Calls_AlwaysAllow_Title: String { return self._s[1919]! }
    public var Username_InvalidTooShort: String { return self._s[1920]! }
    public func Settings_ApplyProxyAlert(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1921]!, self._r[1921]!, [_1, _2])
    }
    public var Weekday_ShortFriday: String { return self._s[1922]! }
    public func Login_BannedPhoneBody(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1923]!, self._r[1923]!, [_0])
    }
    public var Conversation_ClearAll: String { return self._s[1924]! }
    public var Conversation_EditingMessageMediaChange: String { return self._s[1925]! }
    public var Passport_FieldIdentityTranslationHelp: String { return self._s[1926]! }
    public var Call_ReportIncludeLog: String { return self._s[1927]! }
    public func Time_MonthOfYear_m3(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1928]!, self._r[1928]!, [_0])
    }
    public var SharedMedia_EmptyTitle: String { return self._s[1929]! }
    public var Call_PhoneCallInProgressMessage: String { return self._s[1930]! }
    public var Notification_GroupActivated: String { return self._s[1931]! }
    public var Checkout_Name: String { return self._s[1932]! }
    public var Passport_Address_PostcodePlaceholder: String { return self._s[1933]! }
    public func AUTH_REGION(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1934]!, self._r[1934]!, [_1, _2])
    }
    public var Settings_NotificationsAndSounds: String { return self._s[1935]! }
    public var Conversation_EncryptionCanceled: String { return self._s[1936]! }
    public func GroupInfo_InvitationLinkAcceptChannel(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1937]!, self._r[1937]!, [_0])
    }
    public var AccessDenied_SaveMedia: String { return self._s[1938]! }
    public var InviteText_URL: String { return self._s[1939]! }
    public var Passport_CorrectErrors: String { return self._s[1940]! }
    public func Channel_AdminLog_MessageInvitedNameUsername(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1941]!, self._r[1941]!, [_1, _2])
    }
    public var Notifications_Badge_CountUnreadMessages: String { return self._s[1942]! }
    public var Appearance_ReduceMotion: String { return self._s[1943]! }
    public var Compose_GroupTokenListPlaceholder: String { return self._s[1944]! }
    public var Passport_Address_CityPlaceholder: String { return self._s[1945]! }
    public var Passport_InfoFAQ_URL: String { return self._s[1946]! }
    public var Conversation_MessageDeliveryFailed: String { return self._s[1949]! }
    public var InstantPage_TapToOpenLink: String { return self._s[1950]! }
    public var Privacy_PaymentsClear_PaymentInfo: String { return self._s[1951]! }
    public var Notifications_GroupNotifications: String { return self._s[1952]! }
    public var CheckoutInfo_SaveInfoHelp: String { return self._s[1953]! }
    public var Notification_Mute1hMin: String { return self._s[1954]! }
    public var Privacy_TopPeersWarning: String { return self._s[1955]! }
    public var StickerPacksSettings_ArchivedMasks_Info: String { return self._s[1957]! }
    public var ChannelMembers_WhoCanAddMembers_AllMembers: String { return self._s[1959]! }
    public var Channel_Edit_PrivatePublicLinkAlert: String { return self._s[1960]! }
    public var Watch_Conversation_UserInfo: String { return self._s[1961]! }
    public var Application_Name: String { return self._s[1962]! }
    public var Conversation_AddToReadingList: String { return self._s[1963]! }
    public var Conversation_FileDropbox: String { return self._s[1964]! }
    public var Login_PhonePlaceholder: String { return self._s[1965]! }
    public var SocksProxySetup_ProxyEnabled: String { return self._s[1966]! }
    public var Profile_MessageLifetime1d: String { return self._s[1967]! }
    public var CheckoutInfo_ShippingInfoCityPlaceholder: String { return self._s[1968]! }
    public var Notifications_ChannelNotificationsSound: String { return self._s[1969]! }
    public var Calls_CallTabDescription: String { return self._s[1970]! }
    public var Passport_DeletePersonalDetails: String { return self._s[1971]! }
    public var Passport_Address_AddBankStatement: String { return self._s[1972]! }
    public var Resolve_ErrorNotFound: String { return self._s[1973]! }
    public var Watch_Message_Call: String { return self._s[1974]! }
    public var PhotoEditor_FadeTool: String { return self._s[1975]! }
    public var Channel_Setup_TypePublicHelp: String { return self._s[1977]! }
    public var GroupInfo_InviteLink_RevokeAlert_Success: String { return self._s[1980]! }
    public var Channel_Setup_PublicNoLink: String { return self._s[1981]! }
    public var Privacy_Calls_P2PHelp: String { return self._s[1982]! }
    public var Conversation_Info: String { return self._s[1983]! }
    public func Time_TodayAt(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1985]!, self._r[1985]!, [_0])
    }
    public var AutoDownloadSettings_VideosTitle: String { return self._s[1986]! }
    public var Conversation_Processing: String { return self._s[1987]! }
    public var Conversation_RestrictedInline: String { return self._s[1988]! }
    public func InstantPage_AuthorAndDateTitle(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1992]!, self._r[1992]!, [_1, _2])
    }
    public func Watch_LastSeen_AtDate(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1993]!, self._r[1993]!, [_0])
    }
    public var Conversation_Location: String { return self._s[1994]! }
    public var DialogList_PasscodeLockHelp: String { return self._s[1995]! }
    public var Channel_Management_Title: String { return self._s[1996]! }
    public var Notifications_InAppNotificationsPreview: String { return self._s[1997]! }
    public var EnterPasscode_EnterTitle: String { return self._s[1999]! }
    public var ReportPeer_ReasonOther_Title: String { return self._s[2000]! }
    public var Month_GenJanuary: String { return self._s[2001]! }
    public var Conversation_ForwardChats: String { return self._s[2002]! }
    public var Channel_UpdatePhotoItem: String { return self._s[2004]! }
    public var UserInfo_StartSecretChat: String { return self._s[2005]! }
    public var PrivacySettings_LastSeenNobody: String { return self._s[2006]! }
    public func FileSize_MB(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2007]!, self._r[2007]!, [_0])
    }
    public var ChatSearch_SearchPlaceholder: String { return self._s[2010]! }
    public var TwoStepAuth_ConfirmationAbort: String { return self._s[2011]! }
    public var FastTwoStepSetup_HintSection: String { return self._s[2012]! }
    public var TwoStepAuth_SetupPasswordDescription: String { return self._s[2015]! }
    public var TwoStepAuth_SetupPasswordConfirmFailed: String { return self._s[2017]! }
    public func LastSeen_YesterdayAt(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2018]!, self._r[2018]!, [_0])
    }
    public var GroupInfo_GroupHistoryVisible: String { return self._s[2020]! }
    public var AppleWatch_ReplyPresetsHelp: String { return self._s[2021]! }
    public var Localization_LanguageName: String { return self._s[2022]! }
    public var Map_OpenIn: String { return self._s[2023]! }
    public var Message_File: String { return self._s[2024]! }
    public var Call_ReportSend: String { return self._s[2025]! }
    public func Channel_AdminLog_MessageChangedGroupUsername(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2026]!, self._r[2026]!, [_0])
    }
    public func CHAT_MESSAGE_GAME(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2027]!, self._r[2027]!, [_1, _2, _3])
    }
    public func Time_PreciseDate_m1(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2028]!, self._r[2028]!, [_1, _2, _3])
    }
    public var Month_ShortMay: String { return self._s[2031]! }
    public var Tour_Text3: String { return self._s[2032]! }
    public var Contacts_GlobalSearch: String { return self._s[2033]! }
    public var DialogList_LanguageTooltip: String { return self._s[2034]! }
    public var AuthSessions_LogOutApplications: String { return self._s[2035]! }
    public var Map_LoadError: String { return self._s[2036]! }
    public var Settings_ProxyConnecting: String { return self._s[2037]! }
    public var Passport_Language_fa: String { return self._s[2039]! }
    public var AccessDenied_VoiceMicrophone: String { return self._s[2040]! }
    public func CHANNEL_MESSAGE_STICKER(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2043]!, self._r[2043]!, [_1, _2])
    }
    public var Passport_Address_TypeUtilityBillUploadScan: String { return self._s[2044]! }
    public var PrivacySettings_Title: String { return self._s[2045]! }
    public var PasscodeSettings_TurnPasscodeOff: String { return self._s[2048]! }
    public var MediaPicker_AddCaption: String { return self._s[2049]! }
    public var Channel_AdminLog_BanReadMessages: String { return self._s[2050]! }
    public var Channel_Status: String { return self._s[2051]! }
    public var Map_ChooseLocationTitle: String { return self._s[2052]! }
    public var Notifications_ChannelNotifications: String { return self._s[2053]! }
    public var Map_OpenInYandexNavigator: String { return self._s[2054]! }
    public func TwoStepAuth_ConfirmEmailDescription(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2055]!, self._r[2055]!, [_1])
    }
    public var AutoNightTheme_PreferredTheme: String { return self._s[2056]! }
    public var State_WaitingForNetwork: String { return self._s[2057]! }
    public var TwoStepAuth_EmailHelp: String { return self._s[2058]! }
    public var Conversation_StopLiveLocation: String { return self._s[2059]! }
    public var Privacy_SecretChatsLinkPreviewsHelp: String { return self._s[2060]! }
    public var PhotoEditor_SharpenTool: String { return self._s[2061]! }
    public var Common_of: String { return self._s[2062]! }
    public var AuthSessions_Title: String { return self._s[2063]! }
    public var Passport_Scans_UploadNew: String { return self._s[2064]! }
    public var Message_PinnedLiveLocationMessage: String { return self._s[2065]! }
    public var Passport_FieldIdentityDetailsHelp: String { return self._s[2066]! }
    public var PrivacyLastSeenSettings_AlwaysShareWith: String { return self._s[2067]! }
    public var EnterPasscode_EnterPasscode: String { return self._s[2068]! }
    public var Notifications_Reset: String { return self._s[2069]! }
    public func Map_LiveLocationPrivateDescription(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2070]!, self._r[2070]!, [_0])
    }
    public var GroupInfo_InvitationLinkGroupFull: String { return self._s[2071]! }
    public func Channel_AdminLog_MessageChangedChannelUsername(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2073]!, self._r[2073]!, [_0])
    }
    public func CHAT_MESSAGE_DOC(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2074]!, self._r[2074]!, [_1, _2])
    }
    public var Watch_AppName: String { return self._s[2075]! }
    public var ConvertToSupergroup_HelpTitle: String { return self._s[2076]! }
    public var Conversation_TapAndHoldToRecord: String { return self._s[2077]! }
    public func MESSAGE_GIF(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2079]!, self._r[2079]!, [_1])
    }
    public func DialogList_EncryptedChatStartedOutgoing(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2080]!, self._r[2080]!, [_0])
    }
    public var Checkout_PayWithTouchId: String { return self._s[2081]! }
    public var Passport_Language_ko: String { return self._s[2082]! }
    public var Conversation_DiscardVoiceMessageTitle: String { return self._s[2083]! }
    public func CHAT_ADD_YOU(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2084]!, self._r[2084]!, [_1, _2])
    }
    public var CheckoutInfo_ShippingInfoCity: String { return self._s[2085]! }
    public var Group_AdminLog_EmptyText: String { return self._s[2086]! }
    public var AutoDownloadSettings_GroupChats: String { return self._s[2087]! }
    public var TwoStepAuth_AddHintTitle: String { return self._s[2088]! }
    public var Conversation_ClousStorageInfo_Description3: String { return self._s[2090]! }
    public var Notifications_ExceptionsMuted: String { return self._s[2091]! }
    public var Conversation_PinMessageAlertGroup: String { return self._s[2092]! }
    public var TwoStepAuth_RecoveryEmailTitle: String { return self._s[2094]! }
    public var Settings_FAQ_Intro: String { return self._s[2095]! }
    public var PrivacySettings_AuthSessions: String { return self._s[2096]! }
    public func CHAT_MESSAGE_GEOLIVE(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2097]!, self._r[2097]!, [_1, _2])
    }
    public var Passport_Address_Postcode: String { return self._s[2099]! }
    public var Tour_Title5: String { return self._s[2100]! }
    public var ChatAdmins_AllMembersAreAdmins: String { return self._s[2101]! }
    public var Group_Management_AddModeratorHelp: String { return self._s[2102]! }
    public var Channel_Username_CheckingUsername: String { return self._s[2103]! }
    public func DialogList_SingleRecordingVideoMessageSuffix(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2105]!, self._r[2105]!, [_0])
    }
    public func Contacts_AccessDeniedHelpPortrait(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2109]!, self._r[2109]!, [_0])
    }
    public func Checkout_LiabilityAlert(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2110]!, self._r[2110]!, [_1, _1, _1, _2])
    }
    public var Channel_Info_BlackList: String { return self._s[2111]! }
    public var Profile_BotInfo: String { return self._s[2112]! }
    public var Stickers_SuggestAll: String { return self._s[2113]! }
    public var Compose_NewChannel_Members: String { return self._s[2114]! }
    public var Notification_Reply: String { return self._s[2115]! }
    public var Watch_Stickers_Recents: String { return self._s[2117]! }
    public var GroupInfo_SetGroupPhotoStop: String { return self._s[2118]! }
    public var Channel_Stickers_Placeholder: String { return self._s[2119]! }
    public var AttachmentMenu_File: String { return self._s[2120]! }
    public func MESSAGE_STICKER(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2121]!, self._r[2121]!, [_1, _2])
    }
    public var Profile_MessageLifetime5s: String { return self._s[2122]! }
    public var Privacy_ContactsReset: String { return self._s[2124]! }
    public var TwoStepAuth_ChangePasswordDescription: String { return self._s[2125]! }
    public func PINNED_PHOTO(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2126]!, self._r[2126]!, [_1])
    }
    public var Channel_AdminLog_CanAddAdmins: String { return self._s[2129]! }
    public var TwoStepAuth_SetupHint: String { return self._s[2130]! }
    public var Conversation_StatusLeftGroup: String { return self._s[2131]! }
    public var Settings_CopyUsername: String { return self._s[2132]! }
    public var Passport_Identity_CountryPlaceholder: String { return self._s[2133]! }
    public var ChatSettings_AutoDownloadDocuments: String { return self._s[2134]! }
    public var MediaPicker_TapToUngroupDescription: String { return self._s[2135]! }
    public var Conversation_ShareBotLocationConfirmation: String { return self._s[2136]! }
    public var Conversation_DeleteMessagesForMe: String { return self._s[2137]! }
    public var Notification_PassportValuePersonalDetails: String { return self._s[2138]! }
    public var Message_PinnedAnimationMessage: String { return self._s[2139]! }
    public var Passport_FieldIdentityUploadHelp: String { return self._s[2140]! }
    public var SocksProxySetup_ConnectAndSave: String { return self._s[2141]! }
    public var SocksProxySetup_FailedToConnect: String { return self._s[2142]! }
    public var Checkout_ErrorPrecheckoutFailed: String { return self._s[2143]! }
    public var Camera_PhotoMode: String { return self._s[2145]! }
    public func Time_MonthOfYear_m2(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2147]!, self._r[2147]!, [_0])
    }
    public var Channel_About_Placeholder: String { return self._s[2148]! }
    public var Map_Directions: String { return self._s[2150]! }
    public var Channel_About_Title: String { return self._s[2151]! }
    public func MESSAGE_PHOTO(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2152]!, self._r[2152]!, [_1])
    }
    public var Calls_RatingTitle: String { return self._s[2153]! }
    public var SharedMedia_EmptyText: String { return self._s[2154]! }
    public var Channel_Stickers_Searching: String { return self._s[2155]! }
    public var Passport_Address_AddUtilityBill: String { return self._s[2156]! }
    public var Login_PadPhoneHelp: String { return self._s[2157]! }
    public var StickerPacksSettings_ArchivedPacks: String { return self._s[2159]! }
    public var Passport_Language_th: String { return self._s[2160]! }
    public var Channel_ErrorAccessDenied: String { return self._s[2161]! }
    public var Generic_ErrorMoreInfo: String { return self._s[2163]! }
    public var Channel_AdminLog_TitleAllEvents: String { return self._s[2164]! }
    public var Settings_Proxy: String { return self._s[2165]! }
    public var Passport_Language_lt: String { return self._s[2166]! }
    public var TwoStepAuth_ConfirmEmailResendCode: String { return self._s[2167]! }
    public var ChannelMembers_WhoCanAddMembersAllHelp: String { return self._s[2169]! }
    public var Passport_Address_CountryPlaceholder: String { return self._s[2170]! }
    public var ChangePhoneNumberCode_CodePlaceholder: String { return self._s[2171]! }
    public var Camera_SquareMode: String { return self._s[2172]! }
    public func Conversation_EncryptedPlaceholderTitleOutgoing(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2173]!, self._r[2173]!, [_0])
    }
    public var NetworkUsageSettings_CallDataSection: String { return self._s[2174]! }
    public var Login_PadPhoneHelpTitle: String { return self._s[2175]! }
    public var Profile_CreateNewContact: String { return self._s[2176]! }
    public var AccessDenied_VideoMessageMicrophone: String { return self._s[2177]! }
    public var AutoDownloadSettings_VoiceMessagesTitle: String { return self._s[2178]! }
    public var PhotoEditor_VignetteTool: String { return self._s[2179]! }
    public var LastSeen_WithinAWeek: String { return self._s[2180]! }
    public var Widget_NoUsers: String { return self._s[2181]! }
    public var Passport_Identity_DocumentNumber: String { return self._s[2183]! }
    public var Application_Update: String { return self._s[2184]! }
    public var Calls_NewCall: String { return self._s[2185]! }
    public func CHANNEL_MESSAGE_AUDIO(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2186]!, self._r[2186]!, [_1])
    }
    public var DialogList_NoMessagesText: String { return self._s[2187]! }
    public var MaskStickerSettings_Info: String { return self._s[2188]! }
    public var ChatSettings_AutoDownloadTitle: String { return self._s[2189]! }
    public var Passport_FieldAddressHelp: String { return self._s[2190]! }
    public var Passport_Language_dz: String { return self._s[2191]! }
    public var Conversation_FilePhotoOrVideo: String { return self._s[2192]! }
    public var Channel_AdminLog_BanSendStickers: String { return self._s[2193]! }
    public var Common_Next: String { return self._s[2194]! }
    public var Stickers_RemoveFromFavorites: String { return self._s[2195]! }
    public var Watch_Notification_Joined: String { return self._s[2196]! }
    public func Channel_AdminLog_MessageRestrictedNewSetting(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2197]!, self._r[2197]!, [_0])
    }
    public var Passport_DeleteAddress: String { return self._s[2198]! }
    public var ContactInfo_PhoneLabelHome: String { return self._s[2199]! }
    public var GroupInfo_DeleteAndExitConfirmation: String { return self._s[2200]! }
    public var NotificationsSound_Tremolo: String { return self._s[2201]! }
    public var TwoStepAuth_EmailInvalid: String { return self._s[2202]! }
    public var Privacy_ContactsTitle: String { return self._s[2203]! }
    public var Passport_Address_TypeBankStatement: String { return self._s[2205]! }
    public func CHAT_MESSAGE_VIDEO(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2206]!, self._r[2206]!, [_1, _2])
    }
    public var Month_GenJune: String { return self._s[2207]! }
    public var Map_LiveLocationFor15Minutes: String { return self._s[2208]! }
    public func Login_EmailCodeSubject(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2209]!, self._r[2209]!, [_0])
    }
    public func CHAT_TITLE_EDITED(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2210]!, self._r[2210]!, [_1, _2])
    }
    public var ContactInfo_PhoneLabelHomeFax: String { return self._s[2211]! }
    public func NetworkUsageSettings_WifiUsageSince(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2212]!, self._r[2212]!, [_0])
    }
    public var Watch_LastSeen_Lately: String { return self._s[2213]! }
    public var Watch_Compose_CurrentLocation: String { return self._s[2214]! }
    public var DialogList_RecentTitlePeople: String { return self._s[2216]! }
    public var GroupInfo_Notifications: String { return self._s[2217]! }
    public var Call_ReportPlaceholder: String { return self._s[2218]! }
    public func AuthSessions_Message(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2219]!, self._r[2219]!, [_0])
    }
    public func MESSAGE_DOC(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2220]!, self._r[2220]!, [_1])
    }
    public var Group_Username_CreatePrivateLinkHelp: String { return self._s[2221]! }
    public var Notifications_GroupNotificationsSound: String { return self._s[2222]! }
    public var AuthSessions_EmptyTitle: String { return self._s[2223]! }
    public var Privacy_GroupsAndChannels_AlwaysAllow_Title: String { return self._s[2225]! }
    public var Passport_Language_he: String { return self._s[2226]! }
    public func MediaPicker_Nof(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2227]!, self._r[2227]!, [_0])
    }
    public var Common_Create: String { return self._s[2228]! }
    public var Contacts_TopSection: String { return self._s[2229]! }
    public func Map_DirectionsDriveEta(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2230]!, self._r[2230]!, [_0])
    }
    public var PrivacyPolicy_DeclineMessage: String { return self._s[2231]! }
    public var Your_cards_number_is_invalid: String { return self._s[2232]! }
    public func MESSAGE_INVOICE(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2233]!, self._r[2233]!, [_1, _2])
    }
    public var Localization_LanguageCustom: String { return self._s[2234]! }
    public func Channel_AdminLog_MessageRemovedChannelUsername(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2235]!, self._r[2235]!, [_0])
    }
    public var Group_MessagePhotoRemoved: String { return self._s[2236]! }
    public var Appearance_Animations: String { return self._s[2237]! }
    public var UserInfo_AddToExisting: String { return self._s[2238]! }
    public var NotificationsSound_Aurora: String { return self._s[2239]! }
    public func LastSeen_AtDate(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2242]!, self._r[2242]!, [_0])
    }
    public var Conversation_MessageDialogRetry: String { return self._s[2243]! }
    public var Watch_ChatList_NoConversationsTitle: String { return self._s[2244]! }
    public var Passport_Language_my: String { return self._s[2245]! }
    public var Stickers_GroupStickers: String { return self._s[2247]! }
    public var BlockedUsers_Title: String { return self._s[2249]! }
    public func LiveLocationUpdated_TodayAt(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2250]!, self._r[2250]!, [_0])
    }
    public var ContactInfo_PhoneLabelWork: String { return self._s[2251]! }
    public var ChatSettings_ConnectionType_UseSocks5: String { return self._s[2252]! }
    public var Passport_FieldAddressTranslationHelp: String { return self._s[2253]! }
    public var Cache_ClearNone: String { return self._s[2254]! }
    public var SecretTimer_VideoDescription: String { return self._s[2256]! }
    public var Login_InvalidCodeError: String { return self._s[2257]! }
    public var Channel_BanList_BlockedTitle: String { return self._s[2259]! }
    public var Passport_PasswordHelp: String { return self._s[2260]! }
    public var NetworkUsageSettings_Cellular: String { return self._s[2261]! }
    public var Watch_Location_Access: String { return self._s[2262]! }
    public var PrivacySettings_DeleteAccountIfAwayFor: String { return self._s[2264]! }
    public var Channel_AdminLog_EmptyFilterText: String { return self._s[2265]! }
    public var Channel_AdminLog_EmptyText: String { return self._s[2266]! }
    public var PrivacySettings_DeleteAccountTitle: String { return self._s[2267]! }
    public var Passport_Language_ms: String { return self._s[2268]! }
    public var PrivacyLastSeenSettings_CustomShareSettings_Delete: String { return self._s[2269]! }
    public func ENCRYPTED_MESSAGE(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2270]!, self._r[2270]!, [_1])
    }
    public var Watch_LastSeen_WithinAMonth: String { return self._s[2271]! }
    public var PrivacyLastSeenSettings_CustomHelp: String { return self._s[2272]! }
    public var TwoStepAuth_EnterPasswordHelp: String { return self._s[2273]! }
    public var TwoStepAuth_SetupResendEmailCode: String { return self._s[2274]! }
    public var Bot_Stop: String { return self._s[2275]! }
    public var Privacy_GroupsAndChannels_AlwaysAllow_Placeholder: String { return self._s[2276]! }
    public var UserInfo_BotSettings: String { return self._s[2277]! }
    public var Your_cards_expiration_month_is_invalid: String { return self._s[2278]! }
    public var Passport_FieldIdentity: String { return self._s[2279]! }
    public var PrivacyLastSeenSettings_EmpryUsersPlaceholder: String { return self._s[2280]! }
    public var Passport_Identity_EditInternalPassport: String { return self._s[2281]! }
    public func CHANNEL_MESSAGE_ROUND(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2283]!, self._r[2283]!, [_1])
    }
    public var Passport_Identity_LatinNameHelp: String { return self._s[2284]! }
    public var ApplyLanguage_LanguageNotSupportedError: String { return self._s[2285]! }
    public var SocksProxySetup_Port: String { return self._s[2286]! }
    public var Message_VideoMessage: String { return self._s[2288]! }
    public var Conversation_ContextMenuStickerPackInfo: String { return self._s[2289]! }
    public var Login_ResetAccountProtected_LimitExceeded: String { return self._s[2290]! }
    public func CHAT_DELETE_MEMBER(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2291]!, self._r[2291]!, [_1, _2, _3])
    }
    public var Conversation_DiscardVoiceMessageAction: String { return self._s[2292]! }
    public var Camera_Title: String { return self._s[2293]! }
    public var Passport_Identity_IssueDate: String { return self._s[2294]! }
    public var PhotoEditor_CurvesBlue: String { return self._s[2296]! }
    public var Message_PinnedVideoMessage: String { return self._s[2297]! }
    public func Login_EmailPhoneSubject(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2298]!, self._r[2298]!, [_0])
    }
    public var Passport_Phone_UseTelegramNumberHelp: String { return self._s[2300]! }
    public var Group_EditAdmin_PermissionChangeInfo: String { return self._s[2301]! }
    public var TwoStepAuth_Email: String { return self._s[2302]! }
    public var Stickers_SuggestNone: String { return self._s[2303]! }
    public var Map_SendMyCurrentLocation: String { return self._s[2305]! }
    public func MESSAGE_ROUND(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2306]!, self._r[2306]!, [_1])
    }
    public var Passport_Identity_IssueDatePlaceholder: String { return self._s[2307]! }
    public var Watch_Message_Invoice: String { return self._s[2308]! }
    public var Map_Unknown: String { return self._s[2310]! }
    public var Wallpaper_Set: String { return self._s[2312]! }
    public var AccessDenied_Title: String { return self._s[2313]! }
    public var SharedMedia_CategoryLinks: String { return self._s[2314]! }
    public var Localization_LanguageOther: String { return self._s[2315]! }
    public func CHAT_MESSAGES(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2316]!, self._r[2316]!, [_1, _2, _3])
    }
    public var SaveIncomingPhotosSettings_Title: String { return self._s[2317]! }
    public var Passport_Identity_TypeDriversLicense: String { return self._s[2318]! }
    public var FastTwoStepSetup_HintHelp: String { return self._s[2319]! }
    public var Notifications_ExceptionsDefaultSound: String { return self._s[2320]! }
    public var TwoStepAuth_EmailSkipAlert: String { return self._s[2321]! }
    public var ChatSettings_Stickers: String { return self._s[2322]! }
    public var Camera_FlashOff: String { return self._s[2323]! }
    public var TwoStepAuth_Title: String { return self._s[2325]! }
    public var Passport_Identity_Translation: String { return self._s[2326]! }
    public var Checkout_ErrorProviderAccountTimeout: String { return self._s[2327]! }
    public var TwoStepAuth_SetupPasswordEnterPasswordChange: String { return self._s[2328]! }
    public var WebSearch_Images: String { return self._s[2329]! }
    public var Conversation_typing: String { return self._s[2330]! }
    public var Common_Back: String { return self._s[2331]! }
    public var PrivacySettings_DataSettingsHelp: String { return self._s[2333]! }
    public var Passport_Language_es: String { return self._s[2334]! }
    public var Common_Search: String { return self._s[2335]! }
    public func CancelResetAccount_Success(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2336]!, self._r[2336]!, [_0])
    }
    public var Common_No: String { return self._s[2337]! }
    public var Login_EmailNotConfiguredError: String { return self._s[2338]! }
    public var Watch_Suggestion_OK: String { return self._s[2339]! }
    public var Profile_AddToExisting: String { return self._s[2340]! }
    public func Passport_Identity_NativeNameTitle(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2342]!, self._r[2342]!, [_0])
    }
    public func PINNED_NOTEXT(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2343]!, self._r[2343]!, [_1])
    }
    public func Login_EmailCodeBody(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2344]!, self._r[2344]!, [_0])
    }
    public var NotificationsSound_Keys: String { return self._s[2345]! }
    public var Passport_Phone_Title: String { return self._s[2347]! }
    public var Profile_About: String { return self._s[2348]! }
    public func EncryptionKey_Description(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2349]!, self._r[2349]!, [_1, _2])
    }
    public var Conversation_UnreadMessages: String { return self._s[2350]! }
    public func DialogList_LiveLocationSharingTo(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2351]!, self._r[2351]!, [_0])
    }
    public var Tour_Title3: String { return self._s[2352]! }
    public var Passport_Identity_FrontSide: String { return self._s[2353]! }
    public var PrivacyLastSeenSettings_GroupsAndChannelsHelp: String { return self._s[2354]! }
    public var Watch_Contacts_NoResults: String { return self._s[2355]! }
    public var Passport_Language_id: String { return self._s[2356]! }
    public var Passport_Identity_TypeIdentityCardUploadScan: String { return self._s[2357]! }
    public var Watch_UserInfo_MuteTitle: String { return self._s[2358]! }
    public func Privacy_GroupsAndChannels_InviteToGroupError(_ _0: String, _ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2361]!, self._r[2361]!, [_0, _1])
    }
    public func Message_PinnedTextMessage(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2363]!, self._r[2363]!, [_0])
    }
    public func Watch_Time_ShortWeekdayAt(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2364]!, self._r[2364]!, [_1, _2])
    }
    public var Conversation_EmptyGifPanelPlaceholder: String { return self._s[2365]! }
    public var DialogList_Typing: String { return self._s[2366]! }
    public var Notification_CallBack: String { return self._s[2367]! }
    public var Passport_Language_ru: String { return self._s[2368]! }
    public var Map_LocatingError: String { return self._s[2369]! }
    public var InfoPlist_NSFaceIDUsageDescription: String { return self._s[2371]! }
    public var MediaPicker_Send: String { return self._s[2372]! }
    public var ChannelIntro_Title: String { return self._s[2373]! }
    public var AccessDenied_LocationAlwaysDenied: String { return self._s[2375]! }
    public func PINNED_GIF(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2376]!, self._r[2376]!, [_1])
    }
    public func InviteText_SingleContact(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2377]!, self._r[2377]!, [_0])
    }
    public var Passport_Address_TypePassportRegistration: String { return self._s[2378]! }
    public var Channel_EditAdmin_CannotEdit: String { return self._s[2381]! }
    public var LoginPassword_PasswordHelp: String { return self._s[2383]! }
    public var BlockedUsers_Unblock: String { return self._s[2384]! }
    public var AutoDownloadSettings_Cellular: String { return self._s[2385]! }
    public var Passport_Language_ro: String { return self._s[2386]! }
    public func Time_MonthOfYear_m1(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2387]!, self._r[2387]!, [_0])
    }
    public var Appearance_PreviewIncomingText: String { return self._s[2388]! }
    public var Passport_Identity_DateOfBirthPlaceholder: String { return self._s[2389]! }
    public var Notifications_GroupNotificationsAlert: String { return self._s[2390]! }
    public var Paint_Masks: String { return self._s[2391]! }
    public var Appearance_ThemeDayClassic: String { return self._s[2393]! }
    public var StickerPack_ErrorNotFound: String { return self._s[2394]! }
    public var Appearance_ThemeNight: String { return self._s[2395]! }
    public var SecretTimer_ImageDescription: String { return self._s[2396]! }
    public func PINNED_CONTACT(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2397]!, self._r[2397]!, [_1])
    }
    public func FileSize_KB(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2398]!, self._r[2398]!, [_0])
    }
    public var Map_LiveLocationTitle: String { return self._s[2399]! }
    public var Watch_GroupInfo_Title: String { return self._s[2400]! }
    public var Channel_AdminLog_EmptyTitle: String { return self._s[2401]! }
    public var PhotoEditor_Set: String { return self._s[2403]! }
    public var LiveLocation_MenuStopAll: String { return self._s[2404]! }
    public var SocksProxySetup_AddProxy: String { return self._s[2405]! }
    public func Notification_Invited(_ _0: String, _ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2406]!, self._r[2406]!, [_0, _1])
    }
    public var Watch_AuthRequired: String { return self._s[2407]! }
    public var Conversation_EncryptedDescription1: String { return self._s[2408]! }
    public var AppleWatch_ReplyPresets: String { return self._s[2409]! }
    public var Channel_Members_AddAdminErrorNotAMember: String { return self._s[2410]! }
    public var Conversation_EncryptedDescription2: String { return self._s[2411]! }
    public var SocksProxySetup_HostnamePlaceholder: String { return self._s[2412]! }
    public var NetworkUsageSettings_MediaVideoDataSection: String { return self._s[2413]! }
    public var Paint_Edit: String { return self._s[2414]! }
    public var Passport_Language_nl: String { return self._s[2415]! }
    public var LastSeen_Offline: String { return self._s[2416]! }
    public var Login_CodeFloodError: String { return self._s[2417]! }
    public var Conversation_EncryptedDescription3: String { return self._s[2418]! }
    public var Notifications_Badge_IncludePublicGroups: String { return self._s[2420]! }
    public var Conversation_EncryptedDescription4: String { return self._s[2421]! }
    public var AppleWatch_Title: String { return self._s[2423]! }
    public var Contacts_AccessDeniedError: String { return self._s[2424]! }
    public var Conversation_StatusTyping: String { return self._s[2425]! }
    public var Share_Title: String { return self._s[2426]! }
    public var TwoStepAuth_ConfirmationTitle: String { return self._s[2427]! }
    public var Passport_Identity_FilesTitle: String { return self._s[2428]! }
    public var ChatSettings_Title: String { return self._s[2429]! }
    public var AuthSessions_CurrentSession: String { return self._s[2430]! }
    public var Watch_Microphone_Access: String { return self._s[2431]! }
    public func Notification_RenamedChat(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2432]!, self._r[2432]!, [_0])
    }
    public var Conversation_LiveLocation: String { return self._s[2433]! }
    public var Watch_Conversation_GroupInfo: String { return self._s[2434]! }
    public var Passport_Language_fr: String { return self._s[2436]! }
    public var UserInfo_Title: String { return self._s[2437]! }
    public var Passport_Identity_DoesNotExpire: String { return self._s[2438]! }
    public var Map_LiveLocationGroupDescription: String { return self._s[2439]! }
    public var Login_InfoHelp: String { return self._s[2440]! }
    public var ShareMenu_ShareTo: String { return self._s[2442]! }
    public var Message_PinnedGame: String { return self._s[2446]! }
    public var Channel_AdminLog_CanSendMessages: String { return self._s[2447]! }
    public func AutoNightTheme_LocationHelp(_ _0: String, _ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2448]!, self._r[2448]!, [_0, _1])
    }
    public var Notification_RenamedGroup: String { return self._s[2449]! }
    public func Call_PrivacyErrorMessage(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2450]!, self._r[2450]!, [_0])
    }
    public var Passport_Address_Street: String { return self._s[2451]! }
    public var Weekday_Thursday: String { return self._s[2452]! }
    public var FastTwoStepSetup_HintPlaceholder: String { return self._s[2453]! }
    public var PrivacySettings_DataSettings: String { return self._s[2454]! }
    public var ChangePhoneNumberNumber_Title: String { return self._s[2455]! }
    public var NotificationsSound_Bell: String { return self._s[2456]! }
    public var Notifications_Badge_IncludeMutedChats: String { return self._s[2458]! }
    public var TwoStepAuth_EnterPasswordInvalid: String { return self._s[2460]! }
    public var DialogList_SearchSectionMessages: String { return self._s[2461]! }
    public var Media_ShareThisVideo: String { return self._s[2462]! }
    public var Call_ReportIncludeLogDescription: String { return self._s[2463]! }
    public var Preview_DeleteGif: String { return self._s[2464]! }
    public var Passport_Address_OneOfTypeTemporaryRegistration: String { return self._s[2465]! }
    public var Weekday_Saturday: String { return self._s[2466]! }
    public var UserInfo_DeleteContact: String { return self._s[2467]! }
    public var Notifications_ResetAllNotifications: String { return self._s[2468]! }
    public var SocksProxySetup_SaveProxy: String { return self._s[2469]! }
    public var Passport_Identity_Country: String { return self._s[2470]! }
    public var Notification_MessageLifetimeRemovedOutgoing: String { return self._s[2471]! }
    public var Login_ContinueWithLocalization: String { return self._s[2472]! }
    public var GroupInfo_AddParticipant: String { return self._s[2473]! }
    public var Watch_Location_Current: String { return self._s[2474]! }
    public var Checkout_NewCard_SaveInfoHelp: String { return self._s[2475]! }
    public func Settings_ApplyProxyAlertCredentials(_ _1: String, _ _2: String, _ _3: String, _ _4: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2478]!, self._r[2478]!, [_1, _2, _3, _4])
    }
    public var MediaPicker_CameraRoll: String { return self._s[2479]! }
    public var Channel_AdminLog_CanPinMessages: String { return self._s[2480]! }
    public var KeyCommand_NewMessage: String { return self._s[2481]! }
    public func ChannelInfo_AddParticipantConfirmation(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2483]!, self._r[2483]!, [_0])
    }
    public var NetworkUsageSettings_TotalSection: String { return self._s[2484]! }
    public func PINNED_AUDIO(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2485]!, self._r[2485]!, [_1])
    }
    public var Privacy_GroupsAndChannels: String { return self._s[2486]! }
    public func Time_PreciseDate_m12(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2488]!, self._r[2488]!, [_1, _2, _3])
    }
    public var Conversation_DiscardVoiceMessageDescription: String { return self._s[2491]! }
    public var Passport_Address_ScansHelp: String { return self._s[2492]! }
    public func Notification_ChangedGroupPhoto(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2493]!, self._r[2493]!, [_0])
    }
    public var TwoStepAuth_RemovePassword: String { return self._s[2495]! }
    public var Privacy_GroupsAndChannels_CustomHelp: String { return self._s[2497]! }
    public var Passport_Identity_Gender: String { return self._s[2498]! }
    public var UserInfo_NotificationsDisable: String { return self._s[2499]! }
    public var Watch_UserInfo_Service: String { return self._s[2500]! }
    public var Privacy_Calls_CustomHelp: String { return self._s[2502]! }
    public var ChangePhoneNumberCode_Code: String { return self._s[2503]! }
    public var UserInfo_Invite: String { return self._s[2504]! }
    public var CheckoutInfo_ErrorStateInvalid: String { return self._s[2505]! }
    public var DialogList_ClearHistoryConfirmation: String { return self._s[2507]! }
    public var CheckoutInfo_ErrorEmailInvalid: String { return self._s[2509]! }
    public var Month_GenNovember: String { return self._s[2510]! }
    public var UserInfo_NotificationsEnable: String { return self._s[2511]! }
    public func Target_InviteToGroupConfirmation(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2513]!, self._r[2513]!, [_0])
    }
    public var Map_Map: String { return self._s[2514]! }
    public var Map_OpenInMaps: String { return self._s[2515]! }
    public var Common_OK: String { return self._s[2516]! }
    public var TwoStepAuth_SetupHintTitle: String { return self._s[2517]! }
    public var GroupInfo_LeftStatus: String { return self._s[2518]! }
    public var Cache_ClearProgress: String { return self._s[2519]! }
    public var Login_InvalidPhoneError: String { return self._s[2520]! }
    public var Passport_Authorize: String { return self._s[2521]! }
    public var Cache_ClearEmpty: String { return self._s[2522]! }
    public var Map_Search: String { return self._s[2523]! }
    public var Passport_Identity_Translations: String { return self._s[2524]! }
    public var ChannelMembers_GroupAdminsTitle: String { return self._s[2526]! }
    public func Channel_AdminLog_MessageRemovedGroupUsername(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2527]!, self._r[2527]!, [_0])
    }
    public func ApplyLanguage_ChangeLanguageOfficialText(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2528]!, self._r[2528]!, [_1])
    }
    public var ChatSettings_AutomaticPhotoDownload: String { return self._s[2529]! }
    public var Group_ErrorAddTooMuchAdmins: String { return self._s[2531]! }
    public var SocksProxySetup_Password: String { return self._s[2533]! }
    public var Login_SelectCountry_Title: String { return self._s[2534]! }
    public func MESSAGE_PHOTOS(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2535]!, self._r[2535]!, [_1, _2])
    }
    public var Notifications_GroupNotificationsHelp: String { return self._s[2536]! }
    public var PhotoEditor_CropAspectRatioSquare: String { return self._s[2537]! }
    public var Notification_CallOutgoing: String { return self._s[2538]! }
    public var UserInfo_NotificationsDefault: String { return self._s[2539]! }
    public var Weekday_ShortMonday: String { return self._s[2540]! }
    public var Checkout_Receipt_Title: String { return self._s[2541]! }
    public var Channel_Edit_AboutItem: String { return self._s[2542]! }
    public var Login_InfoLastNamePlaceholder: String { return self._s[2543]! }
    public var Channel_Members_AddMembersHelp: String { return self._s[2545]! }
    public func MESSAGE_VIDEO_SECRET(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2546]!, self._r[2546]!, [_1])
    }
    public var Settings_CopyPhoneNumber: String { return self._s[2547]! }
    public var ReportPeer_Report: String { return self._s[2548]! }
    public var Channel_EditMessageErrorGeneric: String { return self._s[2549]! }
    public var Passport_Identity_TranslationsHelp: String { return self._s[2550]! }
    public var LoginPassword_FloodError: String { return self._s[2551]! }
    public var TwoStepAuth_SetupPasswordTitle: String { return self._s[2553]! }
    public var PhotoEditor_DiscardChanges: String { return self._s[2554]! }
    public var Group_UpgradeNoticeText2: String { return self._s[2555]! }
    public func PINNED_ROUND(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2556]!, self._r[2556]!, [_1])
    }
    public func ChannelInfo_ChannelForbidden(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2557]!, self._r[2557]!, [_0])
    }
    public var Conversation_ShareMyContactInfo: String { return self._s[2558]! }
    public var SocksProxySetup_UsernamePlaceholder: String { return self._s[2559]! }
    public func CHANNEL_MESSAGE_GEO(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2560]!, self._r[2560]!, [_1])
    }
    public var Contacts_PhoneNumber: String { return self._s[2561]! }
    public var Group_Info_AdminLog: String { return self._s[2562]! }
    public var Channel_AdminLogFilter_ChannelEventsInfo: String { return self._s[2563]! }
    public var ChatSettings_AutoDownloadEnabled: String { return self._s[2564]! }
    public var StickerPacksSettings_FeaturedPacks: String { return self._s[2565]! }
    public var AuthSessions_LoggedIn: String { return self._s[2566]! }
    public var Month_GenAugust: String { return self._s[2567]! }
    public var Notification_CallCanceled: String { return self._s[2568]! }
    public var Channel_Username_CreatePublicLinkHelp: String { return self._s[2569]! }
    public var StickerPack_Send: String { return self._s[2570]! }
    public var StickerSettings_MaskContextInfo: String { return self._s[2571]! }
    public var Watch_Suggestion_HoldOn: String { return self._s[2572]! }
    public func PINNED_GEO(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2573]!, self._r[2573]!, [_1])
    }
    public var PasscodeSettings_EncryptData: String { return self._s[2574]! }
    public var Common_NotNow: String { return self._s[2575]! }
    public var FastTwoStepSetup_PasswordConfirmationPlaceholder: String { return self._s[2577]! }
    public var PasscodeSettings_Title: String { return self._s[2578]! }
    public var StickerPack_BuiltinPackName: String { return self._s[2579]! }
    public var Appearance_AccentColor: String { return self._s[2581]! }
    public var Watch_Suggestion_BRB: String { return self._s[2582]! }
    public func CHAT_MESSAGE_ROUND(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2583]!, self._r[2583]!, [_1, _2])
    }
    public var Notifications_MessageNotificationsAlert: String { return self._s[2584]! }
    public var Username_InvalidCharacters: String { return self._s[2585]! }
    public var GroupInfo_LabelAdmin: String { return self._s[2586]! }
    public var GroupInfo_Sound: String { return self._s[2587]! }
    public var Channel_EditAdmin_PermissionBanUsers: String { return self._s[2588]! }
    public var InfoPlist_NSCameraUsageDescription: String { return self._s[2589]! }
    public var Passport_Address_AddRentalAgreement: String { return self._s[2590]! }
    public var Wallpaper_PhotoLibrary: String { return self._s[2591]! }
    public var Settings_About: String { return self._s[2592]! }
    public var Privacy_Calls_IntegrationHelp: String { return self._s[2593]! }
    public var ContactInfo_Job: String { return self._s[2594]! }
    public func CHAT_LEFT(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2595]!, self._r[2595]!, [_1, _2])
    }
    public var LoginPassword_ForgotPassword: String { return self._s[2596]! }
    public var Passport_Address_AddTemporaryRegistration: String { return self._s[2598]! }
    public func Map_LiveLocationShortHour(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2599]!, self._r[2599]!, [_0])
    }
    public var Appearance_Preview: String { return self._s[2600]! }
    public func DialogList_AwaitingEncryption(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2601]!, self._r[2601]!, [_0])
    }
    public var Passport_Identity_TypePassport: String { return self._s[2602]! }
    public var ChatSettings_Appearance: String { return self._s[2603]! }
    public var Tour_Title1: String { return self._s[2604]! }
    public var Conversation_EditingCaptionPanelTitle: String { return self._s[2606]! }
    public func Notifications_ExceptionsChangeSound(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2607]!, self._r[2607]!, [_0])
    }
    public var Conversation_LinkDialogCopy: String { return self._s[2608]! }
    public func Notification_PinnedLocationMessage(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2609]!, self._r[2609]!, [_0])
    }
    public func Notification_PinnedPhotoMessage(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2610]!, self._r[2610]!, [_0])
    }
    public func DownloadingStatus(_ _0: String, _ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2611]!, self._r[2611]!, [_0, _1])
    }
    public var Calls_All: String { return self._s[2612]! }
    public func Channel_MessageTitleUpdated(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2613]!, self._r[2613]!, [_0])
    }
    public var Call_CallAgain: String { return self._s[2614]! }
    public var Message_VideoExpired: String { return self._s[2615]! }
    public var TwoStepAuth_RecoveryCodeHelp: String { return self._s[2616]! }
    public func Channel_AdminLog_MessagePromotedNameUsername(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2617]!, self._r[2617]!, [_1, _2])
    }
    public var UserInfo_SendMessage: String { return self._s[2618]! }
    public func Channel_Username_LinkHint(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2619]!, self._r[2619]!, [_0])
    }
    public func AutoDownloadSettings_UpTo(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2620]!, self._r[2620]!, [_0])
    }
    public var Settings_ViewPhoto: String { return self._s[2621]! }
    public var Paint_RecentStickers: String { return self._s[2622]! }
    public var TwoStepAuth_HintPlaceholder: String { return self._s[2623]! }
    public func Passport_PrivacyPolicy(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2624]!, self._r[2624]!, [_1, _2])
    }
    public var ApplyLanguage_ApplyLanguageAction: String { return self._s[2625]! }
    public var TwoStepAuth_EnabledSuccess: String { return self._s[2626]! }
    public var Login_CallRequestState3: String { return self._s[2627]! }
    public var Channel_Edit_LinkItem: String { return self._s[2628]! }
    public var CallSettings_Title: String { return self._s[2630]! }
    public var ChangePhoneNumberNumber_Help: String { return self._s[2631]! }
    public var Passport_InfoTitle: String { return self._s[2632]! }
    public var Watch_Suggestion_Thanks: String { return self._s[2633]! }
    public var Channel_Moderator_Title: String { return self._s[2634]! }
    public var Message_PinnedPhotoMessage: String { return self._s[2635]! }
    public var Notification_SecretChatScreenshot: String { return self._s[2636]! }
    public func Conversation_DeleteMessagesFor(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2637]!, self._r[2637]!, [_0])
    }
    public var Activity_UploadingDocument: String { return self._s[2638]! }
    public var Watch_ChatList_NoConversationsText: String { return self._s[2639]! }
    public var ReportPeer_AlertSuccess: String { return self._s[2640]! }
    public var Tour_Text4: String { return self._s[2641]! }
    public var Channel_Info_Description: String { return self._s[2642]! }
    public var AccessDenied_LocationTracking: String { return self._s[2644]! }
    public var Watch_Compose_Send: String { return self._s[2645]! }
    public var SocksProxySetup_UseForCallsHelp: String { return self._s[2646]! }
    public var Preview_CopyAddress: String { return self._s[2647]! }
    public var Settings_BlockedUsers: String { return self._s[2648]! }
    public var Month_ShortAugust: String { return self._s[2649]! }
    public var Passport_Identity_MainPage: String { return self._s[2650]! }
    public var Passport_FieldAddress: String { return self._s[2652]! }
    public var Channel_AdminLogFilter_AdminsTitle: String { return self._s[2653]! }
    public var Channel_EditAdmin_PermissionChangeInfo: String { return self._s[2654]! }
    public var Notifications_ResetAllNotificationsHelp: String { return self._s[2655]! }
    public var DialogList_EncryptionRejected: String { return self._s[2656]! }
    public var Target_InviteToGroupErrorAlreadyInvited: String { return self._s[2658]! }
    public var AccessDenied_CameraRestricted: String { return self._s[2659]! }
    public var Watch_Message_ForwardedFrom: String { return self._s[2660]! }
    public var CheckoutInfo_ShippingInfoCountryPlaceholder: String { return self._s[2662]! }
    public var Channel_AboutItem: String { return self._s[2663]! }
    public var PhotoEditor_CurvesGreen: String { return self._s[2664]! }
    public var Month_GenJuly: String { return self._s[2665]! }
    public var ContactInfo_URLLabelHomepage: String { return self._s[2666]! }
    public var PrivacyPolicy_DeclineDeclineAndDelete: String { return self._s[2667]! }
    public func DialogList_SingleUploadingFileSuffix(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2669]!, self._r[2669]!, [_0])
    }
    public var ChannelIntro_CreateChannel: String { return self._s[2671]! }
    public var Channel_Management_AddModerator: String { return self._s[2672]! }
    public var Common_ChoosePhoto: String { return self._s[2673]! }
    public var Conversation_Pin: String { return self._s[2674]! }
    public func Login_ResetAccountProtected_Text(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2676]!, self._r[2676]!, [_0])
    }
    public func Channel_AdminLog_EmptyFilterQueryText(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2677]!, self._r[2677]!, [_0])
    }
    public var Camera_TapAndHoldForVideo: String { return self._s[2678]! }
    public var Bot_DescriptionTitle: String { return self._s[2679]! }
    public var FeaturedStickerPacks_Title: String { return self._s[2680]! }
    public var Map_OpenInGoogleMaps: String { return self._s[2682]! }
    public var Notification_MessageLifetime5s: String { return self._s[2683]! }
    public var Contacts_Title: String { return self._s[2686]! }
    public var TwoStepAuth_DisableSuccess: String { return self._s[2687]! }
    public func MESSAGES(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2688]!, self._r[2688]!, [_1, _2])
    }
    public var Channel_Management_AddModeratorHelp: String { return self._s[2691]! }
    public func CHAT_MESSAGE_FWDS(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2692]!, self._r[2692]!, [_1, _2, _3])
    }
    public var Conversation_MessageDialogEdit: String { return self._s[2693]! }
    public var PrivacyLastSeenSettings_Title: String { return self._s[2694]! }
    public var Notifications_ClassicTones: String { return self._s[2696]! }
    public var Conversation_LinkDialogOpen: String { return self._s[2697]! }
    public var Channel_Info_Subscribers: String { return self._s[2698]! }
    public var NotificationsSound_Input: String { return self._s[2699]! }
    public var Conversation_ClousStorageInfo_Description4: String { return self._s[2700]! }
    public var Privacy_Calls_AlwaysAllow: String { return self._s[2701]! }
    public var Privacy_PaymentsClearInfoHelp: String { return self._s[2703]! }
    public var Notification_MessageLifetime1h: String { return self._s[2704]! }
    public func Notification_CreatedChatWithTitle(_ _0: String, _ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2705]!, self._r[2705]!, [_0, _1])
    }
    public var CheckoutInfo_ReceiverInfoEmail: String { return self._s[2706]! }
    public var LastSeen_Lately: String { return self._s[2707]! }
    public var Month_ShortApril: String { return self._s[2708]! }
    public var ConversationProfile_ErrorCreatingConversation: String { return self._s[2709]! }
    public func PHONE_CALL_MISSED(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2710]!, self._r[2710]!, [_1])
    }
    public func Conversation_Kilobytes(_ _0: Int) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2711]!, self._r[2711]!, ["\(_0)"])
    }
    public var Group_ErrorAddBlocked: String { return self._s[2712]! }
    public var TwoStepAuth_AdditionalPassword: String { return self._s[2714]! }
    public var MediaPicker_Videos: String { return self._s[2715]! }
    public var Notification_PassportValueProofOfIdentity: String { return self._s[2716]! }
    public var BlockedUsers_AddNew: String { return self._s[2717]! }
    public var Notifications_DisplayNamesOnLockScreenInfo: String { return self._s[2718]! }
    public var StickerPacksSettings_StickerPacksSection: String { return self._s[2719]! }
    public var Channel_NotificationLoading: String { return self._s[2720]! }
    public var Passport_Language_da: String { return self._s[2722]! }
    public var Passport_Address_Country: String { return self._s[2723]! }
    public func CHAT_RETURNED(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2724]!, self._r[2724]!, [_1, _2])
    }
    public var PhotoEditor_ShadowsTint: String { return self._s[2726]! }
    public var ExplicitContent_AlertTitle: String { return self._s[2728]! }
    public var Channel_AdminLogFilter_EventsLeaving: String { return self._s[2729]! }
    public var Map_LiveLocationFor8Hours: String { return self._s[2730]! }
    public var StickerPack_HideStickers: String { return self._s[2731]! }
    public var Checkout_EnterPassword: String { return self._s[2732]! }
    public var UserInfo_NotificationsEnabled: String { return self._s[2733]! }
    public var InfoPlist_NSLocationAlwaysUsageDescription: String { return self._s[2734]! }
    public var SocksProxySetup_ProxyDetailsTitle: String { return self._s[2735]! }
    public var Appearance_ReduceMotionInfo: String { return self._s[2736]! }
    public var Weekday_ShortTuesday: String { return self._s[2737]! }
    public var Notification_CallIncomingShort: String { return self._s[2738]! }
    public var ConvertToSupergroup_Note: String { return self._s[2739]! }
    public var Login_SendCodeViaSms: String { return self._s[2740]! }
    public var DialogList_Read: String { return self._s[2741]! }
    public var Conversation_EmptyPlaceholder: String { return self._s[2742]! }
    public func Passport_Email_CodeHelp(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2743]!, self._r[2743]!, [_0])
    }
    public var Username_Help: String { return self._s[2744]! }
    public var StickerSettings_ContextHide: String { return self._s[2745]! }
    public var Media_ShareThisPhoto: String { return self._s[2748]! }
    public var Contacts_ShareTelegram: String { return self._s[2749]! }
    public var AutoNightTheme_Scheduled: String { return self._s[2750]! }
    public var Weekday_Sunday: String { return self._s[2751]! }
    public var PrivacySettings_PasscodeAndFaceId: String { return self._s[2753]! }
    public var Settings_ChatBackground: String { return self._s[2754]! }
    public var Login_TermsOfServiceDecline: String { return self._s[2756]! }
    public func AttachmentMenu_SendVideo(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[0 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func Map_ETAMinutes(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[1 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func StickerPack_AddStickerCount(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[2 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func ForwardedVideos(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[3 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func Call_ShortSeconds(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[4 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func Notification_GameScoreSelfSimple(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[5 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func Notification_GameScoreSelfExtended(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[6 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func Notifications_ExceptionMuteExpires_Minutes(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[7 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func Watch_LastSeen_HoursAgo(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[8 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func LiveLocation_MenuChatsCount(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[9 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func MessageTimer_ShortWeeks(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[10 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func MessageTimer_Months(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[11 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func QuickSend_Photos(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[12 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func Media_ShareVideo(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[13 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func SharedMedia_DeleteItemsConfirmation(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[14 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func MuteFor_Hours(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[15 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func MessageTimer_Hours(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[16 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func ForwardedFiles(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[17 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func ForwardedAuthorsOthers(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[18 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func Conversation_LiveLocationMembersCount(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[19 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func ServiceMessage_GameScoreSimple(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[20 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func PasscodeSettings_FailedAttempts(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[21 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func UserCount(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[22 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func DialogList_LiveLocationChatsCount(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[23 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func ForwardedLocations(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[24 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func Call_ShortMinutes(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[25 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func MuteExpires_Days(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[26 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func MessageTimer_Years(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[27 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func Notifications_Exceptions(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[28 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func Contacts_ImportersCount(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[29 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func MessageTimer_ShortMinutes(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[30 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func Watch_LastSeen_MinutesAgo(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[31 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func MuteExpires_Hours(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[32 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func SharedMedia_File(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[33 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func Media_ShareItem(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[34 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func Watch_UserInfo_Mute(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[35 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func SharedMedia_Link(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[36 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func StickerPack_AddMaskCount(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[37 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func StickerPack_StickerCount(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[38 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func MessageTimer_ShortHours(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[39 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func AttachmentMenu_SendItem(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[40 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func LastSeen_HoursAgo(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[41 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func MuteExpires_Minutes(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[42 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func ForwardedAudios(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[43 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func AttachmentMenu_SendPhoto(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[44 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func ServiceMessage_GameScoreSelfExtended(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[45 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func Invitation_Members(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[46 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func Forward_ConfirmMultipleFiles(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[47 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func ForwardedMessages(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[48 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func GroupInfo_ParticipantCount(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[49 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func Conversation_StatusMembers(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[50 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func MessageTimer_ShortDays(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[51 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func ServiceMessage_GameScoreSelfSimple(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[52 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func ForwardedGifs(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[53 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func SharedMedia_Video(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[54 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func Call_Seconds(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[55 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func MessageTimer_Minutes(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[56 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func Conversation_StatusSubscribers(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[57 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func MessageTimer_Days(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[58 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func Notification_GameScoreExtended(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[59 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func MessageTimer_ShortSeconds(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[60 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func PrivacyLastSeenSettings_AddUsers(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[61 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func ForwardedVideoMessages(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[62 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func Notifications_ExceptionMuteExpires_Days(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[63 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func Notifications_ExceptionMuteExpires_Hours(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[64 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func MessageTimer_Seconds(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[65 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func Map_ETAHours(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[66 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func ServiceMessage_GameScoreExtended(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[67 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func Call_Minutes(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[68 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func ForwardedPhotos(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[69 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func Notification_GameScoreSimple(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[70 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func Conversation_StatusOnline(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[71 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func SharedMedia_Generic(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[72 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func LastSeen_MinutesAgo(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[73 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func StickerPack_RemoveStickerCount(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[74 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func ForwardedContacts(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[75 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func SharedMedia_Photo(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[76 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func ForwardedStickers(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[77 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func MessageTimer_Weeks(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[78 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func StickerPack_RemoveMaskCount(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[79 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func Media_SharePhoto(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[80 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func InviteText_ContactsCountText(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[81 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func MuteFor_Days(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[82 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func AttachmentMenu_SendGif(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[83 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func Passport_Scans(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[84 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func LiveLocationUpdated_MinutesAgo(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[85 * 6 + Int(form.rawValue)]!, "\(value)")
    }
        
    init(primaryComponent: PresentationStringsComponent, secondaryComponent: PresentationStringsComponent?) {
        self.primaryComponent = primaryComponent
        self.secondaryComponent = secondaryComponent
        
        self.baseLanguageCode = secondaryComponent?.languageCode ?? primaryComponent.languageCode
        
        let languageCode = primaryComponent.pluralizationRulesCode ?? primaryComponent.languageCode
        var rawCode = languageCode as NSString
        var range = rawCode.range(of: "_")
        if range.location != NSNotFound {
            rawCode = rawCode.substring(to: range.location) as NSString
        }
        range = rawCode.range(of: "-")
        if range.location != NSNotFound {
            rawCode = rawCode.substring(to: range.location) as NSString
        }
        rawCode = rawCode.lowercased as NSString
        var lc: UInt32 = 0
        for i in 0 ..< rawCode.length {
            lc = (lc << 8) + UInt32(rawCode.character(at: i))
        }
        self.lc = lc

        var _s: [Int: String] = [:]
        var _r: [Int: [(Int, NSRange)]] = [:]
        
        let loadedKeyMapping = keyMapping
        
        let sIdList: [Int] = loadedKeyMapping.0
        let sKeyList: [String] = loadedKeyMapping.1
        let sArgIdList: [Int] = loadedKeyMapping.2
        for i in 0 ..< sIdList.count {
            _s[sIdList[i]] = getValue(primaryComponent, secondaryComponent, sKeyList[i])
        }
        for i in 0 ..< sArgIdList.count {
            _r[sArgIdList[i]] = extractArgumentRanges(_s[sArgIdList[i]]!)
        }
        self._s = _s
        self._r = _r

        var _ps: [Int: String] = [:]
        let pIdList: [Int] = loadedKeyMapping.3
        let pKeyList: [String] = loadedKeyMapping.4
        for i in 0 ..< pIdList.count {
            for form in 0 ..< 6 {
                _ps[pIdList[i] * 6 + form] = getValueWithForm(primaryComponent, secondaryComponent, pKeyList[i], PluralizationForm(rawValue: Int32(form))!)
            }
        }
        self._ps = _ps
    }
}

