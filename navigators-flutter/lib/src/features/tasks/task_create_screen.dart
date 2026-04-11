import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../services/task_service.dart';

/// Task creation screen for Admin and Super Navigator roles.
///
/// Form fields: title, description, task type, priority, due date,
/// linked entity (optional), and assignees (multi-select from company members).
class TaskCreateScreen extends ConsumerStatefulWidget {
  const TaskCreateScreen({super.key});

  @override
  ConsumerState<TaskCreateScreen> createState() => _TaskCreateScreenState();
}

class _TaskCreateScreenState extends ConsumerState<TaskCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _taskType = 'custom';
  String _priority = 'medium';
  DateTime? _dueDate;
  String? _linkedEntityType;
  bool _isSubmitting = false;

  // Company members for assignment
  List<Map<String, dynamic>> _members = [];
  final Set<String> _selectedAssignees = {};
  bool _loadingMembers = true;

  static const _taskTypes = {
    'contact_list': 'Contact List',
    'event': 'Event',
    'data_entry': 'Data Entry',
    'custom': 'Custom',
  };

  static const _priorities = {
    'low': 'Low',
    'medium': 'Medium',
    'high': 'High',
    'urgent': 'Urgent',
  };

  static const _entityTypes = {
    'turf': 'Turf',
    'voter': 'Voter',
    'voter_list': 'Voter List',
  };

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadMembers() async {
    try {
      final taskService = ref.read(taskServiceProvider);
      final members = await taskService.listCompanyMembers();
      if (mounted) {
        setState(() {
          _members = members;
          _loadingMembers = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingMembers = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Task'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 1. Title
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title *',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().length < 3) {
                  return 'Title must be at least 3 characters';
                }
                if (value.trim().length > 100) {
                  return 'Title must be 100 characters or less';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // 2. Description
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),

            // 3. Task Type
            DropdownButtonFormField<String>(
              initialValue: _taskType,
              decoration: const InputDecoration(
                labelText: 'Task Type',
                border: OutlineInputBorder(),
              ),
              items: _taskTypes.entries
                  .map((e) => DropdownMenuItem(
                        value: e.key,
                        child: Text(e.value),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _taskType = v!),
            ),
            const SizedBox(height: 16),

            // 4. Priority
            DropdownButtonFormField<String>(
              initialValue: _priority,
              decoration: const InputDecoration(
                labelText: 'Priority',
                border: OutlineInputBorder(),
              ),
              items: _priorities.entries
                  .map((e) => DropdownMenuItem(
                        value: e.key,
                        child: Text(e.value),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _priority = v!),
            ),
            const SizedBox(height: 16),

            // 5. Due Date
            TextFormField(
              readOnly: true,
              decoration: InputDecoration(
                labelText: 'Due Date',
                border: const OutlineInputBorder(),
                suffixIcon: const Icon(Icons.calendar_today),
                hintText: _dueDate != null
                    ? DateFormat.yMMMd().format(_dueDate!)
                    : 'Select a date',
              ),
              controller: TextEditingController(
                text: _dueDate != null
                    ? DateFormat.yMMMd().format(_dueDate!)
                    : '',
              ),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _dueDate ?? DateTime.now(),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) {
                  setState(() => _dueDate = picked);
                }
              },
            ),
            const SizedBox(height: 16),

            // 6. Link to (optional)
            DropdownButtonFormField<String?>(
              initialValue: _linkedEntityType,
              decoration: const InputDecoration(
                labelText: 'Link to (optional)',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('None')),
                ..._entityTypes.entries.map((e) => DropdownMenuItem(
                      value: e.key,
                      child: Text(e.value),
                    )),
              ],
              onChanged: (v) => setState(() => _linkedEntityType = v),
            ),
            const SizedBox(height: 16),

            // 7. Assign to
            Text(
              'Assign to',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            if (_loadingMembers)
              const Center(child: CircularProgressIndicator())
            else if (_members.isEmpty)
              Text(
                'No team members found',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: _members.map((member) {
                  final memberId = member['id'] as String? ?? '';
                  final memberName =
                      member['name'] as String? ?? member['email'] as String? ?? memberId;
                  final isSelected = _selectedAssignees.contains(memberId);

                  return FilterChip(
                    label: Text(memberName),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedAssignees.add(memberId);
                        } else {
                          _selectedAssignees.remove(memberId);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
            const SizedBox(height: 24),

            // Submit button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Create Task'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final taskService = ref.read(taskServiceProvider);
      await taskService.createTask(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        taskType: _taskType,
        priority: _priority,
        dueDate: _dueDate?.toIso8601String(),
        linkedEntityType: _linkedEntityType,
        assigneeIds: _selectedAssignees.toList(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task created successfully')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create task: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}
