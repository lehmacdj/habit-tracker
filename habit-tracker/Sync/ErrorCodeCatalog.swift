import CloudKit
import CoreData
import Foundation

/// Names and explanations for well-known system error codes.
///
/// Swift can't print the name of an `NSError` code, and system
/// `localizedDescription`s are often generic ("The operation couldn't be
/// completed"). The descriptions here paraphrase the doc comments in the
/// SDK headers that define each code; consult them when adding or updating
/// entries (paths are relative to `xcrun --show-sdk-path`):
///
/// - `CKErrorDomain`: `CloudKit.framework/Headers/CKError.h`
/// - `NSCocoaErrorDomain`: `Foundation.framework/Headers/FoundationErrors.h`
///   and `CoreData.framework/Headers/CoreDataErrors.h`
/// - `NSURLErrorDomain`: `Foundation.framework/Headers/NSURLError.h`
///
/// Entries match on SDK constants so the codes are compiler-checked.
enum ErrorCodeCatalog {
  struct Entry: Equatable {
    let name: String
    let summary: String
  }

  static func entry(for error: NSError) -> Entry? {
    switch error.domain {
    case CKError.errorDomain:
      CKError.Code(rawValue: error.code).flatMap(cloudKit)
    case NSCocoaErrorDomain:
      coreData(error.code) ?? foundation(error.code)
    case NSURLErrorDomain:
      urlLoading(error.code)
    default:
      nil
    }
  }

  // MARK: - CloudKit (CKError.h)

  private static func cloudKit(_ code: CKError.Code) -> Entry? {
    switch code {
    case .internalError:
      Entry("internalError", "CloudKit hit a nonrecoverable internal error.")
    case .partialFailure:
      Entry(
        "partialFailure",
        "Some items in the operation failed; see the per-item errors. In "
          + "custom zones the other items fail with batchRequestFailed."
      )
    case .networkUnavailable:
      Entry(
        "networkUnavailable",
        "The network is unavailable. Retry once it's reachable again."
      )
    case .networkFailure:
      Entry(
        "networkFailure",
        "The network is available but CloudKit couldn't be reached. Retry "
          + "with backoff."
      )
    case .badContainer:
      Entry(
        "badContainer",
        "The container is unknown or the app isn't authorized to use it."
      )
    case .serviceUnavailable:
      Entry("serviceUnavailable", "CloudKit is unavailable.")
    case .requestRateLimited:
      Entry(
        "requestRateLimited",
        "CloudKit rate-limited the request. Wait for the retry-after "
          + "interval before retrying."
      )
    case .missingEntitlement:
      Entry(
        "missingEntitlement",
        "The app is missing a required CloudKit entitlement."
      )
    case .notAuthenticated:
      Entry("notAuthenticated", "CloudKit couldn't authenticate the user.")
    case .permissionFailure:
      Entry(
        "permissionFailure",
        "The user doesn't have permission to save or fetch this data. "
          + "Not retryable."
      )
    case .unknownItem:
      Entry("unknownItem", "The specified record doesn't exist.")
    case .invalidArguments:
      Entry(
        "invalidArguments",
        "The request contained invalid information; details may be in "
          + "the error's userInfo."
      )
    case .resultsTruncated:
      Entry("resultsTruncated", "CloudKit truncated the query results.")
    case .serverRecordChanged:
      Entry(
        "serverRecordChanged",
        "The server's copy of the record is newer than the one being saved. "
          + "Merge into the server record and save again."
      )
    case .serverRejectedRequest:
      Entry(
        "serverRejectedRequest",
        "CloudKit rejected the request. Not retryable."
      )
    case .assetFileNotFound:
      Entry("assetFileNotFound", "The specified asset file couldn't be found.")
    case .assetFileModified:
      Entry(
        "assetFileModified",
        "The asset file was modified while it was being saved."
      )
    case .incompatibleVersion:
      Entry(
        "incompatibleVersion",
        "This app version is older than the oldest version CloudKit allows."
      )
    case .constraintViolation:
      Entry(
        "constraintViolation",
        "The server rejected the request because of a unique constraint "
          + "violation."
      )
    case .operationCancelled:
      Entry("operationCancelled", "The operation was cancelled.")
    case .changeTokenExpired:
      Entry(
        "changeTokenExpired",
        "The change token expired; changes must be refetched from scratch."
      )
    case .batchRequestFailed:
      Entry(
        "batchRequestFailed",
        "This item couldn't be saved because another item in the same "
          + "atomic batch failed. Fix the other errors and retry all items."
      )
    case .zoneBusy:
      Entry(
        "zoneBusy",
        "The server is too busy to handle this zone operation. Retry after "
          + "a delay, backing off exponentially."
      )
    case .badDatabase:
      Entry(
        "badDatabase",
        "The operation was submitted to the wrong database."
      )
    case .quotaExceeded:
      Entry(
        "quotaExceeded",
        "Saving would exceed the storage quota. In the private database the "
          + "user needs more iCloud storage."
      )
    case .zoneNotFound:
      Entry("zoneNotFound", "The specified record zone doesn't exist.")
    case .limitExceeded:
      Entry(
        "limitExceeded",
        "The request was too large (roughly 400 items or 2 MB). Split the "
          + "operation in half and retry."
      )
    case .userDeletedZone:
      Entry(
        "userDeletedZone",
        "The user deleted this record zone from Settings."
      )
    case .tooManyParticipants:
      Entry("tooManyParticipants", "The share has too many participants.")
    case .alreadyShared:
      Entry(
        "alreadyShared",
        "The record, its parent, or one of its children is already shared."
      )
    case .referenceViolation:
      Entry(
        "referenceViolation",
        "The target of a record reference couldn't be found."
      )
    case .managedAccountRestricted:
      Entry(
        "managedAccountRestricted",
        "CloudKit access is restricted for this managed account."
      )
    case .participantMayNeedVerification:
      Entry(
        "participantMayNeedVerification",
        "The user isn't a participant of the share and may need to verify "
          + "their email address or phone number."
      )
    case .serverResponseLost:
      Entry(
        "serverResponseLost",
        "The connection was lost before CloudKit responded; the operation "
          + "may or may not have succeeded."
      )
    case .assetNotAvailable:
      Entry("assetNotAvailable", "The specified asset couldn't be accessed.")
    case .accountTemporarilyUnavailable:
      Entry(
        "accountTemporarilyUnavailable",
        "The iCloud account isn't ready for CloudKit yet. Keep local data "
          + "and retry once the account becomes available."
      )
    case .participantAlreadyInvited:
      Entry(
        "participantAlreadyInvited",
        "The user was already invited to this share and must accept the "
          + "existing invitation."
      )
    @unknown default:
      nil
    }
  }

  // MARK: - Core Data (CoreDataErrors.h)

  private static func coreData(_ code: Int) -> Entry? {
    switch code {
    case NSManagedObjectValidationError:
      Entry("managedObjectValidation", "A managed object failed validation.")
    case NSManagedObjectConstraintValidationError:
      Entry(
        "managedObjectConstraintValidation",
        "One or more uniqueness constraints were violated."
      )
    case NSValidationMultipleErrorsError:
      Entry(
        "validationMultipleErrors",
        "Multiple validation errors occurred; see the detailed errors."
      )
    case NSValidationMissingMandatoryPropertyError:
      Entry(
        "validationMissingMandatoryProperty",
        "A non-optional property is nil."
      )
    case NSValidationRelationshipLacksMinimumCountError:
      Entry(
        "validationRelationshipLacksMinimumCount",
        "A to-many relationship has too few destination objects."
      )
    case NSValidationRelationshipExceedsMaximumCountError:
      Entry(
        "validationRelationshipExceedsMaximumCount",
        "A bounded to-many relationship has too many destination objects."
      )
    case NSValidationRelationshipDeniedDeleteError:
      Entry(
        "validationRelationshipDeniedDelete",
        "A relationship with a Deny delete rule isn't empty."
      )
    case NSValidationNumberTooLargeError:
      Entry("validationNumberTooLarge", "A numeric value is too large.")
    case NSValidationNumberTooSmallError:
      Entry("validationNumberTooSmall", "A numeric value is too small.")
    case NSValidationDateTooLateError:
      Entry("validationDateTooLate", "A date value is too late.")
    case NSValidationDateTooSoonError:
      Entry("validationDateTooSoon", "A date value is too early.")
    case NSValidationInvalidDateError:
      Entry(
        "validationInvalidDate",
        "A date value doesn't match the required pattern."
      )
    case NSValidationStringTooLongError:
      Entry("validationStringTooLong", "A string value is too long.")
    case NSValidationStringTooShortError:
      Entry("validationStringTooShort", "A string value is too short.")
    case NSValidationStringPatternMatchingError:
      Entry(
        "validationStringPatternMatching",
        "A string value doesn't match the required pattern."
      )
    case NSValidationInvalidURIError:
      Entry(
        "validationInvalidURI",
        "A URI value can't be represented as a string."
      )
    case NSManagedObjectContextLockingError:
      Entry(
        "managedObjectContextLocking",
        "Couldn't acquire a lock in a managed object context."
      )
    case NSPersistentStoreCoordinatorLockingError:
      Entry(
        "persistentStoreCoordinatorLocking",
        "Couldn't acquire a lock in a persistent store coordinator."
      )
    case NSManagedObjectReferentialIntegrityError:
      Entry(
        "managedObjectReferentialIntegrity",
        "A fault pointed to an object that no longer exists in the store."
      )
    case NSManagedObjectExternalRelationshipError:
      Entry(
        "managedObjectExternalRelationship",
        "A saved object has a relationship to an object in another store."
      )
    case NSManagedObjectMergeError:
      Entry("managedObjectMerge", "The merge policy couldn't merge changes.")
    case NSManagedObjectConstraintMergeError:
      Entry(
        "managedObjectConstraintMerge",
        "The merge policy failed because of conflicting uniqueness "
          + "constraint violations."
      )
    case NSPersistentStoreInvalidTypeError:
      Entry(
        "persistentStoreInvalidType",
        "The persistent store type, format, or version is unknown."
      )
    case NSPersistentStoreTypeMismatchError:
      Entry(
        "persistentStoreTypeMismatch",
        "The store doesn't match the type it was opened as."
      )
    case NSPersistentStoreIncompatibleSchemaError:
      Entry(
        "persistentStoreIncompatibleSchema",
        "The store reported a database-level error while saving, such as a "
          + "missing table or no permission."
      )
    case NSPersistentStoreSaveError:
      Entry(
        "persistentStoreSave",
        "An unclassified error occurred while saving."
      )
    case NSPersistentStoreIncompleteSaveError:
      Entry(
        "persistentStoreIncompleteSave",
        "One or more stores failed during the save."
      )
    case NSPersistentStoreSaveConflictsError:
      Entry(
        "persistentStoreSaveConflicts",
        "An unresolved merge conflict occurred during the save."
      )
    case NSCoreDataError:
      Entry("coreData", "A general Core Data error occurred.")
    case NSPersistentStoreOperationError:
      Entry("persistentStoreOperation", "A persistent store operation failed.")
    case NSPersistentStoreOpenError:
      Entry(
        "persistentStoreOpen",
        "An error occurred while opening the persistent store."
      )
    case NSPersistentStoreTimeoutError:
      Entry(
        "persistentStoreTimeout",
        "Timed out connecting to the persistent store."
      )
    case NSPersistentStoreUnsupportedRequestTypeError:
      Entry(
        "persistentStoreUnsupportedRequestType",
        "The persistent store doesn't support this request type."
      )
    case NSPersistentStoreIncompatibleVersionHashError:
      Entry(
        "persistentStoreIncompatibleVersionHash",
        "The store's entity version hashes don't match the data model."
      )
    case NSMigrationError:
      Entry("migration", "A general migration error occurred.")
    case NSMigrationConstraintViolationError:
      Entry(
        "migrationConstraintViolation",
        "Migration violated a uniqueness constraint."
      )
    case NSMigrationCancelledError:
      Entry("migrationCancelled", "Migration was cancelled.")
    case NSMigrationMissingSourceModelError:
      Entry(
        "migrationMissingSourceModel",
        "Migration couldn't find the source data model."
      )
    case NSMigrationMissingMappingModelError:
      Entry(
        "migrationMissingMappingModel",
        "Migration couldn't find a mapping model."
      )
    case NSMigrationManagerSourceStoreError:
      Entry(
        "migrationManagerSourceStore",
        "Migration failed because of a problem with the source store."
      )
    case NSMigrationManagerDestinationStoreError:
      Entry(
        "migrationManagerDestinationStore",
        "Migration failed because of a problem with the destination store."
      )
    case NSEntityMigrationPolicyError:
      Entry(
        "entityMigrationPolicy",
        "Migration failed in an entity migration policy."
      )
    case NSSQLiteError:
      Entry("sqlite", "A general SQLite error occurred.")
    case NSInferredMappingModelError:
      Entry(
        "inferredMappingModel",
        "Couldn't create an inferred mapping model."
      )
    case NSExternalRecordImportError:
      Entry(
        "externalRecordImport",
        "An error occurred while importing external records."
      )
    case NSPersistentHistoryTokenExpiredError:
      Entry(
        "persistentHistoryTokenExpired",
        "The persistent history token is no longer valid."
      )
    case NSManagedObjectModelReferenceNotFoundError:
      Entry(
        "managedObjectModelReferenceNotFound",
        "The referenced managed object model couldn't be found or loaded."
      )
    case NSStagedMigrationFrameworkVersionMismatchError:
      Entry(
        "stagedMigrationFrameworkVersionMismatch",
        "The store's metadata must be updated to use staged migration."
      )
    case NSStagedMigrationBackwardMigrationError:
      Entry(
        "stagedMigrationBackwardMigration",
        "The staged migration attempted to migrate backwards."
      )
    default:
      nil
    }
  }

  // MARK: - Foundation (FoundationErrors.h)

  private static func foundation(_ code: Int) -> Entry? {
    switch code {
    case NSFileNoSuchFileError:
      Entry("fileNoSuchFile", "The file doesn't exist.")
    case NSFileLockingError:
      Entry("fileLocking", "The file couldn't be locked.")
    case NSFileReadUnknownError:
      Entry("fileReadUnknown", "The file couldn't be read.")
    case NSFileReadNoPermissionError:
      Entry("fileReadNoPermission", "No permission to read the file.")
    case NSFileReadInvalidFileNameError:
      Entry("fileReadInvalidFileName", "The file name is invalid.")
    case NSFileReadCorruptFileError:
      Entry(
        "fileReadCorruptFile",
        "The file is corrupt or in an unexpected format."
      )
    case NSFileReadNoSuchFileError:
      Entry("fileReadNoSuchFile", "The file to read doesn't exist.")
    case NSFileReadInapplicableStringEncodingError:
      Entry(
        "fileReadInapplicableStringEncoding",
        "The file couldn't be read with the requested string encoding."
      )
    case NSFileReadUnsupportedSchemeError:
      Entry("fileReadUnsupportedScheme", "The URL scheme isn't supported.")
    case NSFileReadTooLargeError:
      Entry("fileReadTooLarge", "The file is too large to read.")
    case NSFileReadUnknownStringEncodingError:
      Entry(
        "fileReadUnknownStringEncoding",
        "The file's string encoding couldn't be determined."
      )
    case NSFileWriteUnknownError:
      Entry("fileWriteUnknown", "The file couldn't be written.")
    case NSFileWriteNoPermissionError:
      Entry("fileWriteNoPermission", "No permission to write the file.")
    case NSFileWriteInvalidFileNameError:
      Entry("fileWriteInvalidFileName", "The file name is invalid.")
    case NSFileWriteFileExistsError:
      Entry("fileWriteFileExists", "The destination file already exists.")
    case NSFileWriteInapplicableStringEncodingError:
      Entry(
        "fileWriteInapplicableStringEncoding",
        "The file couldn't be written with the requested string encoding."
      )
    case NSFileWriteUnsupportedSchemeError:
      Entry("fileWriteUnsupportedScheme", "The URL scheme isn't supported.")
    case NSFileWriteOutOfSpaceError:
      Entry("fileWriteOutOfSpace", "There isn't enough disk space.")
    case NSFileWriteVolumeReadOnlyError:
      Entry("fileWriteVolumeReadOnly", "The volume is read-only.")
    #if os(macOS)
    case NSFileManagerUnmountUnknownError:
      Entry("fileManagerUnmountUnknown", "The volume couldn't be unmounted.")
    case NSFileManagerUnmountBusyError:
      Entry(
        "fileManagerUnmountBusy",
        "The volume couldn't be unmounted because it's in use."
      )
    #endif
    case NSKeyValueValidationError:
      Entry("keyValueValidation", "Key-value coding validation failed.")
    case NSFormattingError:
      Entry(
        "formatting",
        "A formatter couldn't convert between a value and a string."
      )
    case NSUserCancelledError:
      Entry("userCancelled", "The user cancelled the operation.")
    case NSFeatureUnsupportedError:
      Entry(
        "featureUnsupported",
        "The feature isn't supported, e.g. by the file system."
      )
    case NSExecutableNotLoadableError:
      Entry(
        "executableNotLoadable",
        "The executable type can't be loaded in this process."
      )
    case NSExecutableArchitectureMismatchError:
      Entry(
        "executableArchitectureMismatch",
        "The executable has no compatible architecture."
      )
    case NSExecutableRuntimeMismatchError:
      Entry(
        "executableRuntimeMismatch",
        "The executable's Objective-C runtime information is incompatible."
      )
    case NSExecutableLoadError:
      Entry("executableLoad", "The executable couldn't be loaded.")
    case NSExecutableLinkError:
      Entry("executableLink", "The executable failed to link.")
    case NSPropertyListReadCorruptError:
      Entry("propertyListReadCorrupt", "The property list couldn't be parsed.")
    case NSPropertyListReadUnknownVersionError:
      Entry(
        "propertyListReadUnknownVersion",
        "The property list version couldn't be determined."
      )
    case NSPropertyListReadStreamError:
      Entry("propertyListReadStream", "Reading the property list failed.")
    case NSPropertyListWriteStreamError:
      Entry("propertyListWriteStream", "Writing the property list failed.")
    case NSPropertyListWriteInvalidError:
      Entry(
        "propertyListWriteInvalid",
        "The object isn't a valid property list."
      )
    case NSXPCConnectionInterrupted:
      Entry("xpcConnectionInterrupted", "The XPC connection was interrupted.")
    case NSXPCConnectionInvalid:
      Entry("xpcConnectionInvalid", "The XPC connection is invalid.")
    case NSXPCConnectionReplyInvalid:
      Entry("xpcConnectionReplyInvalid", "The XPC reply was invalid.")
    case NSXPCConnectionCodeSigningRequirementFailure:
      Entry(
        "xpcConnectionCodeSigningRequirementFailure",
        "The XPC peer failed the code-signing requirement."
      )
    case NSUbiquitousFileUnavailableError:
      Entry(
        "ubiquitousFileUnavailable",
        "The item hasn't been uploaded to iCloud by another device yet."
      )
    case NSUbiquitousFileNotUploadedDueToQuotaError:
      Entry(
        "ubiquitousFileNotUploadedDueToQuota",
        "The item wasn't uploaded because the iCloud account is over quota."
      )
    case NSUbiquitousFileUbiquityServerNotAvailable:
      Entry(
        "ubiquitousFileUbiquityServerNotAvailable",
        "Connecting to the iCloud servers failed."
      )
    case NSUserActivityHandoffFailedError:
      Entry(
        "userActivityHandoffFailed",
        "The user activity's data wasn't available."
      )
    case NSUserActivityConnectionUnavailableError:
      Entry(
        "userActivityConnectionUnavailable",
        "A connection required to continue the activity wasn't available."
      )
    case NSUserActivityRemoteApplicationTimedOutError:
      Entry(
        "userActivityRemoteApplicationTimedOut",
        "The remote app didn't send data in time."
      )
    case NSUserActivityHandoffUserInfoTooLargeError:
      Entry(
        "userActivityHandoffUserInfoTooLarge",
        "The user activity's userInfo was too large."
      )
    case NSCoderReadCorruptError:
      Entry("coderReadCorrupt", "Decoding failed because the data is corrupt.")
    case NSCoderValueNotFoundError:
      Entry("coderValueNotFound", "The requested value wasn't found.")
    case NSCoderInvalidValueError:
      Entry("coderInvalidValue", "The value isn't valid to encode.")
    case NSBundleOnDemandResourceOutOfSpaceError:
      Entry(
        "bundleOnDemandResourceOutOfSpace",
        "Not enough space to download on-demand resources."
      )
    case NSBundleOnDemandResourceExceededMaximumSizeError:
      Entry(
        "bundleOnDemandResourceExceededMaximumSize",
        "Too much on-demand resource content is in use at once."
      )
    case NSBundleOnDemandResourceInvalidTagError:
      Entry(
        "bundleOnDemandResourceInvalidTag",
        "The on-demand resource tag isn't in the app's manifest."
      )
    case NSCloudSharingNetworkFailureError:
      Entry(
        "cloudSharingNetworkFailure",
        "Sharing failed because of a network failure."
      )
    case NSCloudSharingQuotaExceededError:
      Entry(
        "cloudSharingQuotaExceeded",
        "The user doesn't have enough storage to share these items."
      )
    case NSCloudSharingTooManyParticipantsError:
      Entry(
        "cloudSharingTooManyParticipants",
        "The share's participant limit was reached."
      )
    case NSCloudSharingConflictError:
      Entry(
        "cloudSharingConflict",
        "A conflict occurred while saving the share or its root record."
      )
    case NSCloudSharingNoPermissionError:
      Entry(
        "cloudSharingNoPermission",
        "The user doesn't have permission for this sharing action."
      )
    case NSCloudSharingOtherError:
      Entry(
        "cloudSharingOther",
        "A sharing error occurred; see the underlying CloudKit error."
      )
    case NSCompressionFailedError:
      Entry("compressionFailed", "Compressing the data failed.")
    case NSDecompressionFailedError:
      Entry("decompressionFailed", "Decompressing the data failed.")
    default:
      nil
    }
  }

  // MARK: - URL loading (NSURLError.h)

  private static func urlLoading(_ code: Int) -> Entry? {
    switch code {
    case NSURLErrorUnknown:
      Entry("unknown", "The URL loading system hit an uninterpretable error.")
    case NSURLErrorCancelled:
      Entry("cancelled", "The load was cancelled.")
    case NSURLErrorBadURL:
      Entry("badURL", "The URL is malformed.")
    case NSURLErrorTimedOut:
      Entry("timedOut", "The request timed out.")
    case NSURLErrorUnsupportedURL:
      Entry("unsupportedURL", "No protocol handler supports this URL.")
    case NSURLErrorCannotFindHost:
      Entry("cannotFindHost", "The host name couldn't be resolved.")
    case NSURLErrorCannotConnectToHost:
      Entry(
        "cannotConnectToHost",
        "Couldn't connect to the host; it may be down or refusing "
          + "connections."
      )
    case NSURLErrorNetworkConnectionLost:
      Entry(
        "networkConnectionLost",
        "The connection was dropped mid-load."
      )
    case NSURLErrorDNSLookupFailed:
      Entry("dnsLookupFailed", "The DNS lookup failed.")
    case NSURLErrorHTTPTooManyRedirects:
      Entry(
        "httpTooManyRedirects",
        "A redirect loop or too many redirects occurred."
      )
    case NSURLErrorResourceUnavailable:
      Entry("resourceUnavailable", "The resource couldn't be retrieved.")
    case NSURLErrorNotConnectedToInternet:
      Entry(
        "notConnectedToInternet",
        "There's no internet connection and one couldn't be established."
      )
    case NSURLErrorRedirectToNonExistentLocation:
      Entry(
        "redirectToNonExistentLocation",
        "The server redirected without providing a location."
      )
    case NSURLErrorBadServerResponse:
      Entry("badServerResponse", "The server sent bad data.")
    case NSURLErrorUserCancelledAuthentication:
      Entry(
        "userCancelledAuthentication",
        "The user cancelled authentication."
      )
    case NSURLErrorUserAuthenticationRequired:
      Entry(
        "userAuthenticationRequired",
        "Authentication is required to access the resource."
      )
    case NSURLErrorZeroByteResource:
      Entry(
        "zeroByteResource",
        "The server closed the connection without sending the expected data."
      )
    case NSURLErrorCannotDecodeRawData:
      Entry(
        "cannotDecodeRawData",
        "The response data couldn't be decoded."
      )
    case NSURLErrorCannotDecodeContentData:
      Entry(
        "cannotDecodeContentData",
        "The response has an unknown content encoding."
      )
    case NSURLErrorCannotParseResponse:
      Entry("cannotParseResponse", "The response couldn't be parsed.")
    case NSURLErrorAppTransportSecurityRequiresSecureConnection:
      Entry(
        "appTransportSecurityRequiresSecureConnection",
        "App Transport Security blocked an insecure connection."
      )
    case NSURLErrorFileDoesNotExist:
      Entry("fileDoesNotExist", "The file doesn't exist.")
    case NSURLErrorFileIsDirectory:
      Entry("fileIsDirectory", "The requested file is a directory.")
    case NSURLErrorNoPermissionsToReadFile:
      Entry("noPermissionsToReadFile", "No permission to read the resource.")
    case NSURLErrorDataLengthExceedsMaximum:
      Entry(
        "dataLengthExceedsMaximum",
        "The resource is larger than the maximum allowed."
      )
    case NSURLErrorFileOutsideSafeArea:
      Entry("fileOutsideSafeArea", "An internal file operation failed.")
    case NSURLErrorSecureConnectionFailed:
      Entry("secureConnectionFailed", "Establishing a secure connection failed.")
    case NSURLErrorServerCertificateHasBadDate:
      Entry(
        "serverCertificateHasBadDate",
        "The server certificate is expired or not yet valid."
      )
    case NSURLErrorServerCertificateUntrusted:
      Entry(
        "serverCertificateUntrusted",
        "The server certificate is signed by an untrusted root."
      )
    case NSURLErrorServerCertificateHasUnknownRoot:
      Entry(
        "serverCertificateHasUnknownRoot",
        "The server certificate isn't signed by any root."
      )
    case NSURLErrorServerCertificateNotYetValid:
      Entry(
        "serverCertificateNotYetValid",
        "The server certificate isn't valid yet."
      )
    case NSURLErrorClientCertificateRejected:
      Entry("clientCertificateRejected", "The client certificate was rejected.")
    case NSURLErrorClientCertificateRequired:
      Entry(
        "clientCertificateRequired",
        "A client certificate is required."
      )
    case NSURLErrorCannotLoadFromNetwork:
      Entry(
        "cannotLoadFromNetwork",
        "The request must hit the network but was restricted to the cache."
      )
    case NSURLErrorCannotCreateFile:
      Entry("cannotCreateFile", "The download file couldn't be created.")
    case NSURLErrorCannotOpenFile:
      Entry("cannotOpenFile", "The downloaded file couldn't be opened.")
    case NSURLErrorCannotCloseFile:
      Entry("cannotCloseFile", "The downloaded file couldn't be closed.")
    case NSURLErrorCannotWriteToFile:
      Entry("cannotWriteToFile", "The download couldn't be written to disk.")
    case NSURLErrorCannotRemoveFile:
      Entry("cannotRemoveFile", "The downloaded file couldn't be removed.")
    case NSURLErrorCannotMoveFile:
      Entry("cannotMoveFile", "The downloaded file couldn't be moved.")
    case NSURLErrorDownloadDecodingFailedMidStream:
      Entry(
        "downloadDecodingFailedMidStream",
        "Decoding the download failed mid-stream."
      )
    case NSURLErrorDownloadDecodingFailedToComplete:
      Entry(
        "downloadDecodingFailedToComplete",
        "Decoding the download failed after it finished."
      )
    case NSURLErrorInternationalRoamingOff:
      Entry(
        "internationalRoamingOff",
        "The connection needs roaming data, which is turned off."
      )
    case NSURLErrorCallIsActive:
      Entry(
        "callIsActive",
        "A phone call is active on a network without simultaneous data."
      )
    case NSURLErrorDataNotAllowed:
      Entry("dataNotAllowed", "The cellular network disallowed the connection.")
    case NSURLErrorRequestBodyStreamExhausted:
      Entry(
        "requestBodyStreamExhausted",
        "A body stream was needed but not provided."
      )
    case NSURLErrorBackgroundSessionRequiresSharedContainer:
      Entry(
        "backgroundSessionRequiresSharedContainer",
        "The background session needs a shared container identifier."
      )
    case NSURLErrorBackgroundSessionInUseByAnotherProcess:
      Entry(
        "backgroundSessionInUseByAnotherProcess",
        "Another process is already connected to the background session."
      )
    case NSURLErrorBackgroundSessionWasDisconnected:
      Entry(
        "backgroundSessionWasDisconnected",
        "The app was suspended or exited during a background data task."
      )
    default:
      nil
    }
  }
}

private extension ErrorCodeCatalog.Entry {
  init(_ name: String, _ summary: String) {
    self.init(name: name, summary: summary)
  }
}
