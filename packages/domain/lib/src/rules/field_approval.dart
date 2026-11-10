import '../enums.dart';
import '../models/sports_field.dart';

bool isFieldPublic(SportsField field) =>
    field.isActive && field.approvalStatus == ApprovalStatus.approved;

bool canTransitionApprovalStatus(ApprovalStatus from, ApprovalStatus to) {
  return switch (from) {
    ApprovalStatus.pending => to == ApprovalStatus.approved || to == ApprovalStatus.rejected,
    ApprovalStatus.approved => to == ApprovalStatus.rejected,
    ApprovalStatus.rejected => to == ApprovalStatus.pending,
  };
}

ApprovalStatus approvalStatusAfterOwnerEdit(ApprovalStatus current) =>
    current == ApprovalStatus.rejected ? ApprovalStatus.pending : current;
