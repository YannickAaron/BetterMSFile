# BetterMSFile Stability & UX Fixes — Design Spec

**Date:** 2026-03-26
**Scope:** Targeted fixes for bugs, silent failures, and UX gaps found during code review.

## 1. Search Scope Pagination Fix

**Problem:** "My OneDrive" scope filters results client-side after Graph returns 25 items. Total count and `moreAvailable` are wrong.

**Fix:** After client-side filtering, adjust the returned `SearchResult`:
- Set `total` to filtered count
- If filtered count < page size but API says more available, the UI should still show "Load More" since subsequent pages may contain OneDrive results

**Files:** `SearchService.swift`

## 2. User-Facing Error Feedback

**Problem:** Downloads, QuickLook, and drag-drop moves fail silently (print only).

**Fix:**
- Add `@State var operationError: String?` to `FileListView`
- Show `.alert` on download failure, QuickLook failure
- Drag-drop move already shows rollback; add error alert for move failures too
- Move `frecencyVM.recordAccess` to AFTER successful file open (not before download)

**Files:** `FileListView.swift`

## 3. Sidebar Error + Retry State

**Problem:** Sidebar shows "No teams or sites found" whether loading failed or sites are genuinely empty.

**Fix:**
- Add `errorMessage: String?` to `SidebarViewModel`
- In sidebar UI, show error text + "Retry" button when `errorMessage` is set
- Distinguish loading / error / empty states

**Files:** `SidebarViewModel.swift`, `MainView.swift`

## 4. Defensive Fixes

- Remove `first!` force-unwrap on Downloads directory in `FileListView`
- Clean up temp files from previous sessions on app launch
- Add `Task.isCancelled` checks before file operations in QuickLook
- Fix QuickLook: only record frecency AFTER successful preview

**Files:** `FileListView.swift`, `BetterMSFileApp.swift`

## 5. Background Auth Expiry Handling

**Problem:** `backgroundRefresh` catches token errors silently. User stays "authenticated" but all API calls fail.

**Fix:** In the catch block, check if error is auth-related. If so, set `authService.isAuthenticated = false` to trigger the login screen.

**Files:** `AppState.swift`, `AuthService.swift`
