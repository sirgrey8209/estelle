import 'package:flutter/material.dart';
import '../../../core/constants/colors.dart';
import '../../../data/models/pending_request.dart';

class QuestionRequestView extends StatefulWidget {
  final QuestionRequest request;
  final void Function(int questionIndex, String answer) onSelectAnswer;
  final void Function(dynamic answer) onSubmit;

  const QuestionRequestView({
    super.key,
    required this.request,
    required this.onSelectAnswer,
    required this.onSubmit,
  });

  @override
  State<QuestionRequestView> createState() => _QuestionRequestViewState();
}

class _QuestionRequestViewState extends State<QuestionRequestView> {
  final _customController = TextEditingController();

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  bool get _isSingleQuestion => widget.request.questions.length == 1;

  void _submitCustomAnswer() {
    final text = _customController.text.trim();
    if (text.isEmpty) return;
    widget.onSubmit(text);
    _customController.clear();
  }

  void _submitAllAnswers() {
    final answers = widget.request.questions
        .asMap()
        .entries
        .map((e) => widget.request.answers[e.key] ?? '')
        .toList();

    widget.onSubmit(answers.length == 1 ? answers.first : answers);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Questions
        ...widget.request.questions.asMap().entries.map((entry) {
          final qIdx = entry.key;
          final q = entry.value;
          final selectedAnswer = widget.request.answers[qIdx];

          return Padding(
            padding: EdgeInsets.only(bottom: qIdx < widget.request.questions.length - 1 ? 12 : 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Question header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: NordColors.nord10,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        q.header,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: NordColors.nord6,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        q.question,
                        style: const TextStyle(
                          fontSize: 14,
                          color: NordColors.nord5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Options
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: q.options.map((opt) {
                    final isSelected = selectedAnswer == opt;
                    return _OptionButton(
                      label: opt,
                      isSelected: isSelected,
                      onPressed: () {
                        if (_isSingleQuestion) {
                          widget.onSubmit(opt);
                        } else {
                          widget.onSelectAnswer(qIdx, opt);
                        }
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          );
        }),

        // Submit button for multi-question
        if (!_isSingleQuestion) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton(
                onPressed: widget.request.answers.length >= widget.request.questions.length
                    ? _submitAllAnswers
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: NordColors.nord10,
                  foregroundColor: NordColors.nord6,
                ),
                child: Text(
                  '제출 (${widget.request.answers.length}/${widget.request.questions.length})',
                ),
              ),
            ],
          ),
        ],

        // Custom input for single question
        if (_isSingleQuestion) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _customController,
                  style: const TextStyle(
                    fontSize: 13,
                    color: NordColors.nord5,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Or type custom answer...',
                    hintStyle: const TextStyle(color: NordColors.nord3),
                    filled: true,
                    fillColor: NordColors.nord0,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: NordColors.nord2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                  ),
                  onSubmitted: (_) => _submitCustomAnswer(),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _OptionButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onPressed;

  const _OptionButton({
    required this.label,
    required this.isSelected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? NordColors.nord10 : NordColors.nord2,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isSelected ? NordColors.nord10 : NordColors.nord3,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: isSelected ? NordColors.nord6 : NordColors.nord5,
            ),
          ),
        ),
      ),
    );
  }
}
