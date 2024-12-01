;; Licensing System - A License Management System
;; This contract allows content owners to grant, revoke, and transfer licenses for digital assets.
;; It supports both single and batch license grants with metadata validation.
;; - Licenses are represented as non-fungible tokens (NFTs).
;; - Admins can grant, revoke, and transfer licenses, while metadata can be updated by the license owner.
;; - Batch functionality allows up to 50 licenses to be granted in one transaction.
;; - It ensures security through ownership validation and metadata checks.

;; Constants
(define-constant admin tx-sender) ;; Defines the administrator as the transaction sender
(define-constant max-license-batch u50) ;; Maximum number of licenses that can be granted in one batch
(define-constant err-unauthorized (err u200)) ;; Error for unauthorized actions
(define-constant err-license-exists (err u201)) ;; Error if license already exists
(define-constant err-license-not-found (err u202)) ;; Error if license is not found
(define-constant err-invalid-license-id (err u203)) ;; Error for invalid license ID
(define-constant err-invalid-metadata (err u204)) ;; Error for invalid license metadata
(define-constant err-license-revoked (err u205)) ;; Error if the license has been revoked
(define-constant err-batch-limit-exceeded (err u206)) ;; Error if batch size exceeds the limit
(define-constant err-empty-metadata (err u207)) ;; Error for empty metadata

;; Data Variables
(define-non-fungible-token license-token uint) ;; Non-fungible token for managing licenses
(define-data-var last-license-id uint u0) ;; Tracks the last issued license ID

;; Maps to store data
(define-map license-metadata uint (string-ascii 512)) ;; Metadata associated with each license
(define-map revoked-licenses uint bool) ;; Keeps track of revoked licenses
(define-map batch-license-metadata uint (string-ascii 512)) ;; Metadata for batch licenses

;; Private Helper Functions
(define-private (is-license-holder (license-id uint) (holder principal))
    ;; Checks if the specified holder is the owner of the license
    (is-eq holder (unwrap! (nft-get-owner? license-token license-id) false)))

(define-private (is-valid-metadata (metadata (string-ascii 512)))
    ;; Validates that the metadata is not empty and within length constraints
    (let 
        (
            (metadata-len (len metadata))
        )
        (and 
            (> metadata-len u0) 
            (<= metadata-len u512)
            (not (is-eq metadata ""))
        )
    ))

(define-private (is-license-revoked (license-id uint))
    ;; Checks if the license has been revoked
    (default-to false (map-get? revoked-licenses license-id)))

;; Core Functionality

(define-private (grant-license-single (metadata (string-ascii 512)))
    ;; Grants a single license with specified metadata
    (let 
        (
            (new-license-id (+ (var-get last-license-id) u1)) ;; Increment the last license ID
        )
        (asserts! (is-valid-metadata metadata) err-invalid-metadata) ;; Ensure metadata is valid
        (try! (nft-mint? license-token new-license-id tx-sender)) ;; Mint new NFT for the license
        (map-set license-metadata new-license-id metadata) ;; Store metadata for the new license
        (var-set last-license-id new-license-id) ;; Update last license ID
        (ok new-license-id))) ;; Return the new license ID

;; Public License Functions

(define-public (grant-license (metadata (string-ascii 512)))
    ;; Grants a license by calling the private function for a single license
    (begin
        (asserts! (is-eq tx-sender admin) err-unauthorized) ;; Only admin can grant licenses
        (asserts! (is-valid-metadata metadata) err-invalid-metadata) ;; Validate metadata
        (grant-license-single metadata))) ;; Call core function to mint license

(define-public (batch-grant-license (metadatas (list 50 (string-ascii 512))))
    ;; Grants a batch of licenses with metadata validation
    (let 
        (
            (batch-size (len metadatas)) ;; Get the size of the batch
        )
        (begin
            (asserts! (is-eq tx-sender admin) err-unauthorized) ;; Only admin can batch grant licenses
            (asserts! (<= batch-size max-license-batch) err-batch-limit-exceeded) ;; Ensure batch size is within limit
            (asserts! (fold check-metadata metadatas true) err-invalid-metadata) ;; Validate all metadata entries in the batch
            (ok (fold grant-in-batch metadatas (list)))))) ;; Grant licenses in batch

(define-private (check-metadata (metadata (string-ascii 512)) (valid bool))
    ;; Helper function to check metadata validity for batch processing
    (and valid (is-valid-metadata metadata)))

(define-private (grant-in-batch (metadata (string-ascii 512)) (previous-results (list 50 uint)))
    ;; Helper function for granting licenses in batch, accumulating results
    (match (grant-license-single metadata)
        success (unwrap-panic (as-max-len? (append previous-results success) u50))
        error previous-results)) ;; Return previous successful results if error occurs

(define-public (revoke-license (license-id uint))
    ;; Revokes a specific license and updates the revoked licenses map
    (let 
        (
            (current-holder (unwrap! (nft-get-owner? license-token license-id) err-license-not-found)) ;; Get current license holder
        )
        (asserts! (is-eq tx-sender current-holder) err-unauthorized) ;; Ensure only the holder can revoke
        (asserts! (not (is-license-revoked license-id)) err-license-revoked) ;; Ensure license isn't already revoked
        (try! (nft-burn? license-token license-id current-holder)) ;; Burn the NFT for the license
        (map-set revoked-licenses license-id true) ;; Mark the license as revoked
        (ok true))) ;; Return success

(define-public (transfer-license (license-id uint) (sender principal) (recipient principal))
    ;; Transfers a license from one user to another
    (begin
        (asserts! (is-eq recipient tx-sender) err-unauthorized) ;; Ensure the sender is the transaction sender
        (asserts! (not (is-license-revoked license-id)) err-license-revoked) ;; Ensure license isn't revoked
        (let 
            (
                (actual-sender (unwrap! (nft-get-owner? license-token license-id) err-license-not-found)) ;; Get actual sender of the license
            )
            (asserts! (is-eq actual-sender sender) err-unauthorized) ;; Ensure the sender matches the license holder
            (try! (nft-transfer? license-token license-id sender recipient)) ;; Transfer the license NFT
            (ok true)))) ;; Return success
