import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/medication_model.dart';
import '../../shared/components/components.dart';
import '../../l10n/app_strings.dart';
import '../../shared/styles/colors.dart';
import '../../shared/utils/validators.dart';
import 'cubit/care_circle_cubit.dart';
import 'cubit/care_circle_states.dart';

/// Patient's Care Circle tab: caregivers, pending invites, invite flow.
class CareCircleScreen extends StatelessWidget {
  const CareCircleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => CareCircleCubit()..load(),
      child: const _CareCircleView(),
    );
  }
}

class _CareCircleView extends StatelessWidget {
  const _CareCircleView();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CareCircleCubit, CareCircleStates>(
      listener: (context, state) {
        // The invite sheet pops immediately — without this snackbar the
        // sender had NO confirmation the invite actually went out.
        if (state is CareCircleInviteSent) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(context.tr('circle.inviteSent'))));
        }
      },
      builder: (context, state) {
        final cubit = context.read<CareCircleCubit>();

        return Scaffold(
          appBar: AppBar(title: Text(context.tr('circle.title')), centerTitle: true),
          bottomNavigationBar: const PatientBottomNav(currentIndex: 3),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _openInviteSheet(context, cubit),
            icon: const Icon(Icons.person_add),
            label: Text(context.tr('circle.invite')),
          ),
          body: state is CareCircleLoading
              ? const Center(child: CircularProgressIndicator())
              : state is CareCircleError && cubit.accepted.isEmpty
                  ? ErrorWithRetry(
                      message: context.trv(state.message),
                      onRetry: cubit.load,
                    )
                  : RefreshIndicator(
                      onRefresh: cubit.load,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                        children: [
                          if (state is CareCircleError)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Text(context.trv(state.message),
                                  style: const TextStyle(color: AppColors.danger)),
                            ),
                          _SectionTitle(context.tr('circle.linked')),
                          if (cubit.accepted.isEmpty)
                            _EmptyHint(context
                                .tr('circle.empty')),
                          ...cubit.accepted.map((r) => _CaregiverGlassCard(
                                relationship: r,
                                busy: state is CareCircleActionLoading &&
                                    state.relationshipId == r.id,
                                onRevoke: () => _confirmRevoke(context, cubit, r),
                              )),
                          if (cubit.pending.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            _SectionTitle(context.tr('circle.pending')),
                            ...cubit.pending.map((r) => _PendingGlassCard(
                                  relationship: r,
                                  busy: state is CareCircleActionLoading &&
                                      state.relationshipId == r.id,
                                  onAccept: () =>
                                      cubit.respond(r.id, accept: true),
                                  onReject: () =>
                                      cubit.respond(r.id, accept: false),
                                )),
                          ],
                        ],
                      ),
                    ),
        );
      },
    );
  }

  void _openInviteSheet(BuildContext context, CareCircleCubit cubit) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _InviteCaregiverSheet(cubit: cubit),
    );
  }

  void _confirmRevoke(
      BuildContext context, CareCircleCubit cubit, RelationshipModel r) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('circle.revokeTitle')),
        content: Text(
            context.tr('circle.revokeBody').replaceAll('{name}', r.otherPartyName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(context.tr('common.cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () {
              Navigator.of(dialogContext).pop();
              cubit.revoke(r.id);
            },
            child: Text(context.tr('circle.revoke')),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(text,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w700)),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final String text;
  const _EmptyHint(this.text);

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(text,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center),
      ),
    );
  }
}

class _CaregiverGlassCard extends StatelessWidget {
  final RelationshipModel relationship;
  final bool busy;
  final VoidCallback onRevoke;

  const _CaregiverGlassCard({
    required this.relationship,
    required this.busy,
    required this.onRevoke,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
          child: const Icon(Icons.person, color: AppColors.primary),
        ),
        title: Text(relationship.otherPartyName.isEmpty
            ? context.tr('circle.caregiver')
            : relationship.otherPartyName),
        subtitle: Text(relationship.relation.isEmpty
            ? context.tr('circle.caregiverSubtitle')
            : relationship.relation),
        trailing: busy
            ? const SizedBox(
                width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
            : IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: context.tr('circle.revoke'),
                onPressed: onRevoke,
              ),
      ),
    );
  }
}

class _PendingGlassCard extends StatelessWidget {
  final RelationshipModel relationship;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _PendingGlassCard({
    required this.relationship,
    required this.busy,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.hourglass_top, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.tr('circle.inviteFrom').replaceAll('{name}', relationship.otherPartyName),
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (busy)
              const Center(child: CircularProgressIndicator(strokeWidth: 2))
            else
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: onAccept,
                      child: Text(context.tr('circle.accept')),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onReject,
                      child: Text(context.tr('circle.reject')),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _InviteCaregiverSheet extends StatefulWidget {
  final CareCircleCubit cubit;
  const _InviteCaregiverSheet({required this.cubit});

  @override
  State<_InviteCaregiverSheet> createState() => _InviteCaregiverSheetState();
}

class _InviteCaregiverSheetState extends State<_InviteCaregiverSheet> {
  final _emailController = TextEditingController();
  final _relationController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailController.dispose();
    _relationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.tr('circle.inviteTitle'),
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(context.tr('circle.inviteHint'),
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 16),
              DefaultFormField(
                controller: _emailController,
                label: context.tr('circle.inviteEmail'),
                hint: 'name@example.com / 010xxxxxxxx',
                prefixIcon: Icons.alternate_email,
                keyboardType: TextInputType.emailAddress,
                validator: (v) => AppValidators.isValidEmailOrPhone(v ?? '')
                    ? null
                    : context.tr('circle.invalidIdentifier'),
              ),
              const SizedBox(height: 12),
              DefaultFormField(
                controller: _relationController,
                label: context.tr('circle.inviteRelation'),
                prefixIcon: Icons.family_restroom,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      widget.cubit.invite(
                        _emailController.text.trim(),
                        _relationController.text.trim(),
                      );
                      Navigator.of(context).pop();
                    }
                  },
                  child: Text(context.tr('circle.inviteSend')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
