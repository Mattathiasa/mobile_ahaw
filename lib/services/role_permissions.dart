// Dart port of mahibere-ahaw/src/lib/rolePermissions.ts
// Keeps the same permission keys, default role mappings, and resolver logic.

// ─── All permission keys ──────────────────────────────────────────────────────

const List<String> allPermissions = [
  // Pages / Nav
  'canViewDashboard',
  'canViewAnnouncements',
  'canViewPlans',
  'canViewReports',
  'canViewMembers',
  'canViewMeetings',
  'canViewFinance',
  'canViewChurchRules',
  'canViewHigeDenb',
  'canViewStrategicPlan',
  'canViewDocuments',
  'canViewHierarchy',
  'canViewMissionary',
  'canViewTeachings',
  'canViewVolunteer',
  'canViewUserManagement',
  'canViewSettings',
  'canViewNotifications',
  'canViewInventory',
  'canViewHR',
  // Actions
  'canCreateAnnouncement',
  'canEditAnnouncement',
  'canDeleteAnnouncement',
  'canCreatePlan',
  'canDeletePlan',
  'canCreateReport',
  'canViewAllReports',
  'canCommentOnReport',
  'canAddMembers',
  'canEditMembers',
  'canDeleteMembers',
  'canExportData',
  'canScheduleMeeting',
  'canDeleteMeeting',
  'canAddTransaction',
  'canCreateBudget',
  'canGenerateFinancialReport',
  'canUploadDocuments',
  'canDeleteDocuments',
  'canCreateTeaching',
  'canSubmitMissionaryApplication',
  'canSubmitMissionaryReport',
  // Dashboard view level
  'canViewFullDashboard',
  'canViewLimitedDashboard',
];

// ─── Default role → permissions (mirrors DEFAULT_ROLE_PERMISSIONS in TS) ─────

const Map<String, List<String>> defaultRolePermissions = {
  'Sinodos': allPermissions, // all

  'KuamiSinodos': [
    'canViewDashboard', 'canViewAnnouncements', 'canViewPlans', 'canViewReports',
    'canViewMembers', 'canViewMeetings', 'canViewFinance', 'canViewChurchRules',
    'canViewHigeDenb', 'canViewStrategicPlan', 'canViewDocuments', 'canViewHierarchy',
    'canViewMissionary', 'canViewTeachings', 'canViewVolunteer', 'canViewSettings',
    'canViewNotifications', 'canViewInventory', 'canViewHR',
    'canCreateAnnouncement', 'canEditAnnouncement', 'canDeleteAnnouncement',
    'canCreatePlan', 'canDeletePlan',
    'canCreateReport', 'canViewAllReports', 'canCommentOnReport',
    'canAddMembers', 'canEditMembers', 'canDeleteMembers', 'canExportData',
    'canScheduleMeeting', 'canDeleteMeeting',
    'canAddTransaction', 'canCreateBudget', 'canGenerateFinancialReport',
    'canUploadDocuments', 'canDeleteDocuments',
    'canCreateTeaching',
    'canSubmitMissionaryApplication', 'canSubmitMissionaryReport',
    'canViewFullDashboard',
  ],

  'Memriya': [
    'canViewDashboard', 'canViewAnnouncements', 'canViewPlans', 'canViewReports',
    'canViewMembers', 'canViewMeetings', 'canViewFinance', 'canViewChurchRules',
    'canViewHigeDenb', 'canViewStrategicPlan', 'canViewDocuments', 'canViewMissionary',
    'canViewTeachings', 'canViewVolunteer', 'canViewUserManagement', 'canViewSettings',
    'canViewNotifications', 'canViewInventory', 'canViewHR',
    'canCreateAnnouncement', 'canEditAnnouncement', 'canDeleteAnnouncement',
    'canCreatePlan', 'canDeletePlan',
    'canCreateReport', 'canViewAllReports', 'canCommentOnReport',
    'canAddMembers', 'canEditMembers', 'canDeleteMembers', 'canExportData',
    'canScheduleMeeting', 'canDeleteMeeting',
    'canAddTransaction', 'canCreateBudget', 'canGenerateFinancialReport',
    'canUploadDocuments', 'canDeleteDocuments',
    'canCreateTeaching',
    'canSubmitMissionaryApplication', 'canSubmitMissionaryReport',
    'canViewFullDashboard',
  ],

  'Zone': [
    'canViewDashboard', 'canViewAnnouncements', 'canViewPlans', 'canViewReports',
    'canViewMembers', 'canViewMeetings', 'canViewFinance', 'canViewChurchRules',
    'canViewHigeDenb', 'canViewStrategicPlan', 'canViewDocuments', 'canViewHierarchy',
    'canViewMissionary', 'canViewTeachings', 'canViewVolunteer', 'canViewSettings',
    'canViewNotifications',
    'canCreatePlan', 'canCreateReport', 'canCommentOnReport',
    'canAddMembers', 'canEditMembers', 'canExportData',
    'canAddTransaction',
    'canUploadDocuments',
    'canSubmitMissionaryApplication', 'canSubmitMissionaryReport',
    'canViewLimitedDashboard',
  ],

  'Atbiya': [
    'canViewDashboard', 'canViewAnnouncements', 'canViewPlans', 'canViewReports',
    'canViewMembers', 'canViewMeetings', 'canViewFinance', 'canViewChurchRules',
    'canViewHigeDenb', 'canViewDocuments', 'canViewMissionary', 'canViewTeachings',
    'canViewVolunteer', 'canViewSettings', 'canViewNotifications',
    'canCreatePlan', 'canCreateReport', 'canCommentOnReport',
    'canAddMembers', 'canEditMembers',
    'canAddTransaction',
    'canUploadDocuments',
    'canSubmitMissionaryApplication', 'canSubmitMissionaryReport',
    'canViewLimitedDashboard',
  ],

  'EnkesekaseMaikel': [
    'canViewDashboard', 'canViewAnnouncements', 'canViewPlans', 'canViewReports',
    'canViewMembers', 'canViewMeetings', 'canViewChurchRules', 'canViewHigeDenb',
    'canViewDocuments', 'canViewTeachings', 'canViewVolunteer', 'canViewSettings',
    'canViewNotifications',
    'canCreateReport', 'canCommentOnReport',
    'canAddMembers',
    'canSubmitMissionaryApplication',
    'canViewLimitedDashboard',
  ],

  'HiyawanMahderat': [
    'canViewDashboard', 'canViewAnnouncements', 'canViewMembers', 'canViewMeetings',
    'canViewChurchRules', 'canViewHigeDenb', 'canViewTeachings', 'canViewVolunteer',
    'canViewSettings', 'canViewNotifications',
    'canAddMembers',
    'canSubmitMissionaryApplication',
    'canViewLimitedDashboard',
  ],
};

// ─── Resolver (mirrors resolvePermissions() in TS) ───────────────────────────

/// Merges role-level defaults with Firestore overrides and per-user overrides.
Set<String> resolvePermissions({
  required String hierarchyLevel,
  required String userId,
  required Map<String, List<String>> roleOverrides,
  required Map<String, Map<String, bool>> userOverrides,
}) {
  // Start from Firestore role override, or fall back to default
  final rolePerms = roleOverrides[hierarchyLevel] ??
      defaultRolePermissions[hierarchyLevel] ??
      defaultRolePermissions['HiyawanMahderat']!;

  final perms = Set<String>.from(rolePerms);

  // Apply per-user overrides on top
  final userOverride = userOverrides[userId];
  if (userOverride != null) {
    for (final entry in userOverride.entries) {
      if (entry.value) {
        perms.add(entry.key);
      } else {
        perms.remove(entry.key);
      }
    }
  }

  return perms;
}
