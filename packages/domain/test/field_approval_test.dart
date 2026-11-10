import 'package:domain/domain.dart';
import 'package:test/test.dart';

void main() {
  SportsField field({bool isActive = true, ApprovalStatus status = ApprovalStatus.approved}) =>
      SportsField(
        id: const FieldId(1),
        ownerId: const UserId(3),
        name: 'Arena',
        description: 'Mali fudbal',
        sport: SportType.football,
        address: 'Ulica 1',
        city: 'Beograd',
        pricePerHour: 3000,
        contactPhone: '060',
        confirmationMode: ConfirmationMode.manual,
        isActive: isActive,
        approvalStatus: status,
      );

  group('isFieldPublic', () {
    test('javno je samo aktivno i odobreno', () {
      expect(isFieldPublic(field()), isTrue);
      expect(isFieldPublic(field(status: ApprovalStatus.pending)), isFalse);
      expect(isFieldPublic(field(status: ApprovalStatus.rejected)), isFalse);
      expect(isFieldPublic(field(isActive: false)), isFalse);
    });

    test('teren bez navedenog stanja je odobren, kao do sada u klijentima', () {
      expect(field().approvalStatus, ApprovalStatus.approved);
    });
  });

  group('canTransitionApprovalStatus', () {
    const allowed = {
      (ApprovalStatus.pending, ApprovalStatus.approved),
      (ApprovalStatus.pending, ApprovalStatus.rejected),
      (ApprovalStatus.approved, ApprovalStatus.rejected),
      (ApprovalStatus.rejected, ApprovalStatus.pending),
    };

    for (final from in ApprovalStatus.values) {
      for (final to in ApprovalStatus.values) {
        final expected = allowed.contains((from, to));
        test('${from.name} → ${to.name}: ${expected ? 'dozvoljeno' : 'zabranjeno'}', () {
          expect(canTransitionApprovalStatus(from, to), expected);
        });
      }
    }
  });

  group('approvalStatusAfterOwnerEdit', () {
    test('odbijen teren posle izmene ponovo čeka odobrenje', () {
      expect(approvalStatusAfterOwnerEdit(ApprovalStatus.rejected), ApprovalStatus.pending);
    });

    test('odobren i teren na čekanju zadržavaju stanje', () {
      expect(approvalStatusAfterOwnerEdit(ApprovalStatus.approved), ApprovalStatus.approved);
      expect(approvalStatusAfterOwnerEdit(ApprovalStatus.pending), ApprovalStatus.pending);
    });
  });

  test('copyWith menja stanje odobrenosti i razlog', () {
    final rejected = field(status: ApprovalStatus.pending)
        .copyWith(approvalStatus: ApprovalStatus.rejected, rejectionReason: 'Nedostaju slike');

    expect(rejected.approvalStatus, ApprovalStatus.rejected);
    expect(rejected.rejectionReason, 'Nedostaju slike');
    expect(rejected.name, 'Arena');
  });
}
