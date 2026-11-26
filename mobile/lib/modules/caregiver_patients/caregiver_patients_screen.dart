import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../app_router.dart';
import '../../services/notifications_poller.dart';
import '../../shared/components/components.dart';
import '../../l10n/app_strings.dart';
import '../../shared/styles/colors.dart';
import '../../shared/utils/validators.dart';
import 'cubit/caregiver_patients_cubit.dart';
import 'cubit/caregiver_patients_states.dart';

/// Caregiver home: accepted patients + pending invitations to accept/reject.
class CaregiverPatientsScreen extends StatelessWidget {
  const CaregiverPatientsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => CaregiverPatientsCubit()..load(),
      child: const _CaregiverPatientsView(),
    );
  }
}

class _CaregiverPatientsView extends StatelessWidget {
  const _CaregiverPatientsView();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CaregiverPatientsCubit, CaregiverPatientsStates>(
      listener: (context, state) {
        if (state is CaregiverInviteSent) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(context.tr('cg.inviteSent'))));
        } else if (state is CaregiverPatientsError &&
            context.read<CaregiverPatientsCubit>().patients.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(context.trv(state.message))));
        }
      },
      builder: (context, state) {
        final cubit = context.read<CaregiverPatientsCubit>();
        return Scaffold(
          appBar: AppBar(
            title: Text(context.tr('cg.patients')),
            centerTitle: true,
            actions: [
              ValueListenableBuilder<int>(
                valueListenable: NotificationsPoller.instance.unread,
                builder: (_, unread, __) => Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.notifications_none),
                      tooltip: context.tr('today.notifications'),
                      onPressed: () => context.push(Routes.notifications),
                    ),
                    if (unread > 0)
                      PositionedDirectional(
                        top: 8,
                        end: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.danger,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            unread > 99 ? '99+' : '$unread',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                tooltip: context.tr('today.settings'),
                onPressed: () => context.push(Routes.settings),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _openFollowPatientSheet(context, cubit),
            icon: const Icon(Icons.person_add_alt_1),
            label: Text(context.tr('cg.followPatient')),
          ),
          body: state is CaregiverPatientsLoading
              ? const Center(child: CircularProgressIndicator())
              : state is CaregiverPatientsError &&
                      cubit.patients.isEmpty &&
                      cubit.pendingInvites.isEmpty
                  ? ErrorWithRetry(
                      message: context.trv(state.message), onRetry: () => cubit.load())
                  : RefreshIndicator(
                      onRefresh: () => cubit.load(),
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                        children: [
                          if (cubit.pendingInvites.isNotEmpty) ...[
                            Text(context.tr('cg.pendingInvites'),
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 8),
                            ...cubit.pendingInvites.map((rel) => GlassCard(
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          context.tr('cg.requestFrom').replaceAll('{name}', rel.patientName.isNotEmpty ? rel.patientName : context.tr('cg.patient')),
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleSmall,
                                        ),
                                        const SizedBox(height: 8),
                                        if (state is CaregiverPatientsActionLoading &&
                                            state.relationshipId == rel.id)
                                          const Center(
                                              child: CircularProgressIndicator(
                                                  strokeWidth: 2))
                                        else
                                          Row(
                                            children: [
                                              Expanded(
                                                child: FilledButton(
                                                  onPressed: () => cubit
                                                      .respond(rel.id,
                                                          accept: true),
                                                  child: Text(context.tr('circle.accept')),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: OutlinedButton(
                                                  onPressed: () => cubit
                                                      .respond(rel.id,
                                                          accept: false),
                                                  child: Text(context.tr('circle.reject')),
                                                ),
                                              ),
                                            ],
                                          ),
                                      ],
                                    ),
                                  ),
                                )),
                            const SizedBox(height: 16),
                          ],
                          Text(context.tr('cg.linkedPatients'),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 8),
                          if (cubit.patients.isEmpty)
                            GlassCard(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Text(
                                  context.tr('cg.noPatients'),
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ),
                            )
                          else
                            ...cubit.patients.map((rel) => GlassCard(
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: AppColors.primary
                                          .withValues(alpha: 0.1),
                                      child: const Icon(Icons.person_outline,
                                          color: AppColors.primary),
                                    ),
                                    title: Text(rel.patientName.isNotEmpty
                                        ? rel.patientName
                                        : context.tr('cg.patient')),
                                    subtitle: Text(
                                        '${context.tr('cg.relation')}: ${rel.relation.isEmpty ? '-' : rel.relation}'),
                                    trailing: const Icon(
                                        Icons.arrow_forward_ios_rounded,
                                        size: 16),
                                    onTap: () => context.push(
                                        Routes.patientDetail(rel.patientId),
                                        extra: rel),
                                  ),
                                )),
                        ],
                      ),
                    ),
        );
      },
    );
  }

  void _openFollowPatientSheet(
      BuildContext context, CaregiverPatientsCubit cubit) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _FollowPatientSheet(cubit: cubit),
    );
  }
}

class _FollowPatientSheet extends StatefulWidget {
  final CaregiverPatientsCubit cubit;
  const _FollowPatientSheet({required this.cubit});

  @override
  State<_FollowPatientSheet> createState() => _FollowPatientSheetState();
}

class _FollowPatientSheetState extends State<_FollowPatientSheet> {
  final _identifier = TextEditingController();
  final _relation = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _identifier.dispose();
    _relation.dispose();
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(context.tr('cg.followPatientTitle'),
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(context.tr('cg.followPatientHint'),
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 16),
              DefaultFormField(
                controller: _identifier,
                label: context.tr('forgot.identifier'),
                hint: 'patient@medimind.app / 010xxxxxxxx',
                prefixIcon: Icons.alternate_email,
                validator: (v) => AppValidators.isValidEmailOrPhone(v ?? '')
                    ? null
                    : context.tr('circle.invalidIdentifier'),
              ),
              const SizedBox(height: 12),
              DefaultFormField(
                controller: _relation,
                label: context.tr('circle.inviteRelation'),
                prefixIcon: Icons.family_restroom,
              ),
              const SizedBox(height: 16),
              DefaultButton(
                label: context.tr('circle.inviteSend'),
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    widget.cubit.requestFollow(
                        _identifier.text.trim(), _relation.text.trim());
                    Navigator.of(context).pop();
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
