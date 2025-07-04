/// Copyright 2015-2022 Google Inc. All rights reserved.
/// Copyright 2024 North Pole Security, Inc.
///
/// Licensed under the Apache License, Version 2.0 (the "License");
/// you may not use this file except in compliance with the License.
/// You may obtain a copy of the License at
///
///     http://www.apache.org/licenses/LICENSE-2.0
///
/// Unless required by applicable law or agreed to in writing, software
/// distributed under the License is distributed on an "AS IS" BASIS,
/// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
/// See the License for the specific language governing permissions and
/// limitations under the License.

#import <Foundation/Foundation.h>

///
///  These enums are used in various places throughout the Santa client code.
///  The integer values are also stored in the database and so shouldn't be changed.
///

typedef NS_ENUM(NSInteger, SNTAction) {
  SNTActionUnset,

  // REQUESTS
  // If an operation is awaiting a cache decision from a similar operation
  // currently being processed, it will poll about every 5 ms for an answer.
  SNTActionRequestBinary,

  // RESPONSES
  SNTActionRespondAllow,
  SNTActionRespondAllowNoCache,
  SNTActionRespondDeny,
  SNTActionRespondAllowCompiler,

  // If an operation is awaiting a cache decision via hold-an-ask, additional
  // executions will be automatically blocked.
  SNTActionRespondHold,

  // FOLLOWUP ACTIONS
  // Executions that were previously put on hold can either be allowed or denied.
  SNTActionHoldAllowed,
  SNTActionHoldDenied,
};

#define RESPONSE_VALID(x) \
  (x == SNTActionRespondAllow || x == SNTActionRespondDeny || x == SNTActionRespondAllowCompiler)

// Supported Rule Types
//
// Note: These enum values should be in order of decreasing precedence as
// evaluated by Santa. When adding new enum values, leave some space so that
// additional rules can be added without violating this. The ordering isn't
// strictly necessary but improves readability and may preemptively prevent
// issues should SQLite behavior change.
typedef NS_ENUM(NSInteger, SNTRuleType) {
  SNTRuleTypeUnknown = 0,

  SNTRuleTypeCDHash = 500,
  SNTRuleTypeBinary = 1000,
  SNTRuleTypeSigningID = 2000,
  SNTRuleTypeCertificate = 3000,
  SNTRuleTypeTeamID = 4000,
};

typedef NS_ENUM(NSInteger, SNTRuleState) {
  SNTRuleStateUnknown,

  SNTRuleStateAllow = 1,
  SNTRuleStateBlock = 2,
  SNTRuleStateSilentBlock = 3,
  SNTRuleStateRemove = 4,

  SNTRuleStateAllowCompiler = 5,
  SNTRuleStateAllowTransitive = 6,
  SNTRuleStateAllowLocalBinary = 7,
  SNTRuleStateAllowLocalSigningID = 8,

  SNTRuleStateCEL = 9,
};

typedef NS_ENUM(NSInteger, SNTClientMode) {
  SNTClientModeUnknown,
  SNTClientModeMonitor = 1,
  SNTClientModeLockdown = 2,
  SNTClientModeStandalone = 3,
};

typedef NS_ENUM(uint64_t, SNTEventState) {
  // Bits 0-15 bits store non-decision types
  SNTEventStateUnknown = 0,
  SNTEventStateBundleBinary = 1,

  // Bits 16-39 store deny decision types
  SNTEventStateBlockUnknown = 1ULL << 16,
  SNTEventStateBlockBinary = 1ULL << 17,
  SNTEventStateBlockCertificate = 1ULL << 18,
  SNTEventStateBlockScope = 1ULL << 19,
  SNTEventStateBlockTeamID = 1ULL << 20,
  SNTEventStateBlockLongPath = 1ULL << 21,
  SNTEventStateBlockSigningID = 1ULL << 22,
  SNTEventStateBlockCDHash = 1ULL << 23,

  // Bits 40-63 store allow decision types
  SNTEventStateAllowUnknown = 1ULL << 40,
  SNTEventStateAllowBinary = 1ULL << 41,
  SNTEventStateAllowCertificate = 1ULL << 42,
  SNTEventStateAllowScope = 1ULL << 43,
  SNTEventStateAllowCompilerBinary = 1ULL << 44,
  SNTEventStateAllowTransitive = 1ULL << 45,
  SNTEventStateAllowPendingTransitive = 1ULL << 46,
  SNTEventStateAllowTeamID = 1ULL << 47,
  SNTEventStateAllowSigningID = 1ULL << 48,
  SNTEventStateAllowCDHash = 1ULL << 49,
  SNTEventStateAllowLocalBinary = 1ULL << 50,
  SNTEventStateAllowLocalSigningID = 1ULL << 51,
  SNTEventStateAllowCompilerSigningID = 1ULL << 52,
  SNTEventStateAllowCompilerCDHash = 1ULL << 53,

  // Block and Allow masks
  SNTEventStateBlock = 0xFFFFFFULL << 16,
  SNTEventStateAllow = 0xFFFFFFULL << 40,
};

// This enum type is used to indicate what should be done with the related bundle events that are
// generated when an initiating blocked bundle event occurs.
typedef NS_ENUM(NSInteger, SNTBundleEventAction) {
  SNTBundleEventActionDropEvents,
  SNTBundleEventActionStoreEvents,
  SNTBundleEventActionSendEvents,
};

// Indicates where to store event logs.
typedef NS_ENUM(NSInteger, SNTEventLogType) {
  SNTEventLogTypeSyslog,
  SNTEventLogTypeFilelog,
  SNTEventLogTypeProtobuf,
  SNTEventLogTypeJSON,
  SNTEventLogTypeNull,
};

// The return status of a sync.
typedef NS_ENUM(NSInteger, SNTSyncStatusType) {
  SNTSyncStatusTypeSuccess,
  SNTSyncStatusTypePreflightFailed,
  SNTSyncStatusTypeEventUploadFailed,
  SNTSyncStatusTypeRuleDownloadFailed,
  SNTSyncStatusTypePostflightFailed,
  SNTSyncStatusTypeTooManySyncsInProgress,
  SNTSyncStatusTypeMissingSyncBaseURL,
  SNTSyncStatusTypeMissingMachineID,
  SNTSyncStatusTypeDaemonTimeout,
  SNTSyncStatusTypeSyncStarted,
  SNTSyncStatusTypeFailedXPCConnection,
  SNTSyncStatusTypeUnknown,
};

typedef NS_ENUM(NSInteger, SNTSyncContentEncoding) {
  SNTSyncContentEncodingNone,
  SNTSyncContentEncodingDeflate,
  SNTSyncContentEncodingGzip,
};

typedef NS_ENUM(NSInteger, SNTMetricFormatType) {
  SNTMetricFormatTypeUnknown,
  SNTMetricFormatTypeRawJSON,
  SNTMetricFormatTypeMonarchJSON,
};

typedef NS_ENUM(NSInteger, SNTOverrideFileAccessAction) {
  SNTOverrideFileAccessActionNone,
  SNTOverrideFileAccessActionAuditOnly,
  SNTOverrideFileAccessActionDiable,
};

typedef NS_ENUM(NSInteger, SNTDeviceManagerStartupPreferences) {
  SNTDeviceManagerStartupPreferencesNone,
  SNTDeviceManagerStartupPreferencesUnmount,
  SNTDeviceManagerStartupPreferencesForceUnmount,
  SNTDeviceManagerStartupPreferencesRemount,
  SNTDeviceManagerStartupPreferencesForceRemount,
};

typedef NS_ENUM(NSInteger, SNTSyncType) {
  SNTSyncTypeNormal,
  SNTSyncTypeClean,
  SNTSyncTypeCleanAll,
};

typedef NS_ENUM(NSInteger, SNTRuleCleanup) {
  SNTRuleCleanupNone,
  SNTRuleCleanupAll,
  SNTRuleCleanupNonTransitive,
};

typedef NS_ENUM(NSInteger, SNTSigningStatus) {
  SNTSigningStatusUnsigned,
  SNTSigningStatusInvalid,
  SNTSigningStatusAdhoc,
  SNTSigningStatusDevelopment,
  SNTSigningStatusProduction,
};

typedef NS_ENUM(NSInteger, SNTPushNotificationStatus) {
  SNTPushNotificationStatusUnknown,
  SNTPushNotificationStatusDisabled,
  SNTPushNotificationStatusDisconnected,
  SNTPushNotificationStatusConnected,
};

#ifdef __cplusplus

enum class FileAccessPolicyDecision {
  kNoPolicy,
  kDenied,
  kDeniedInvalidSignature,
  kAllowed,
  kAllowedReadAccess,
  kAllowedAuditOnly,
};

#endif

static const char *kSantaDPath =
    "/Applications/Santa.app/Contents/Library/SystemExtensions/"
    "com.northpolesec.santa.daemon.systemextension/Contents/MacOS/com.northpolesec.santa.daemon";
static const char *kSantaAppPath = "/Applications/Santa.app";
