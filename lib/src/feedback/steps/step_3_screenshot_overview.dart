import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart';
import 'package:wiredash/src/core/services/error_report.dart';
import 'package:wiredash/src/core/theme/color_ext.dart';
import 'package:wiredash/src/core/theme/wirecons.dart';
import 'package:wiredash/src/core/theme/wiredash_theme.dart';
import 'package:wiredash/src/core/widgets/backdrop/step_page_scaffold.dart';
import 'package:wiredash/src/core/widgets/backdrop/wiredash_backdrop.dart';
import 'package:wiredash/src/core/widgets/tron/animated_fade_widget_switcher.dart';
import 'package:wiredash/src/core/widgets/tron/tron_button.dart';
import 'package:wiredash/src/core/widgets/tron/tron_icon.dart';
import 'package:wiredash/src/core/wiredash_localizations_ext.dart';
import 'package:wiredash/src/feedback/data/feedback_item.dart';
import 'package:wiredash/src/feedback/feedback_flow.dart';
import 'package:wiredash/src/feedback/feedback_model.dart';
import 'package:wiredash/src/feedback/ui/base_click_target.dart';
import 'package:wiredash/src/utils/standard_kt.dart';

/// Picks an image from [source] and attaches its bytes to the feedback as a
/// screenshot.
///
/// Returns `true` when the picker completed normally (whether the user picked
/// an image or cancelled). Returns `false` when picking failed — typically
/// because permissions were denied — so the caller can surface a localized
/// error. Failures are also reported through [reportWiredashError].
Future<bool> _pickAndAttachPhoto(
  BuildContext context,
  ImageSource source,
) async {
  final feedback = context.readFeedbackModel;
  XFile? image;
  try {
    image = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1920,
      imageQuality: 85,
    );
  } catch (e, s) {
    reportWiredashError(
      e,
      s,
      'Failed to pick photo from ${source == ImageSource.camera ? 'camera' : 'gallery'} for feedback',
    );
    return false;
  }
  if (image == null) return true;
  final bytes = await image.readAsBytes();
  await feedback.addPhotoAttachment(bytes);
  return true;
}

/// Inline error message styled for the screenshot step. Hidden when [message]
/// is `null`.
class _PhotoPickerError extends StatelessWidget {
  const _PhotoPickerError({required this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    if (message == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(
        message!,
        style: TextStyle(color: context.theme.errorColor),
      ),
    );
  }
}

class Step3ScreenshotOverview extends StatefulWidget {
  const Step3ScreenshotOverview({super.key});

  @override
  State<Step3ScreenshotOverview> createState() =>
      _Step3ScreenshotOverviewState();
}

class _Step3ScreenshotOverviewState extends State<Step3ScreenshotOverview> {
  @override
  Widget build(BuildContext context) {
    return AnimatedFadeWidgetSwitcher(
      clipBehavior: Clip.none,
      fadeInOnEnter: false,
      duration: const Duration(milliseconds: 300),
      onSwitch: () {
        WiredashBackdrop.maybeOf(context)?.animateSizeChange = true;
      },
      child: () {
        if (!context.watchFeedbackModel.hasAttachments) {
          return const Step3NoAttachments();
        }
        return const Step3WithGallery();
      }(),
    );
  }
}

class Step3NoAttachments extends StatefulWidget {
  const Step3NoAttachments({
    super.key,
  });

  @override
  State<Step3NoAttachments> createState() => _Step3NoAttachmentsState();
}

class _Step3NoAttachmentsState extends State<Step3NoAttachments> {
  String? _photoError;

  Future<void> _handlePick(ImageSource source) async {
    setState(() => _photoError = null);
    final ok = await _pickAndAttachPhoto(context, source);
    if (!mounted || ok) return;
    setState(() {
      _photoError = context
          .l10n.feedbackStep3ScreenshotOverviewPhotoPermissionDeniedMessage;
    });
  }

  @override
  Widget build(BuildContext context) {
    return StepPageScaffold(
      indicator: const FeedbackProgressIndicator(
        flowStatus: FeedbackFlowStatus.screenshotsOverview,
      ),
      title: Text(context.l10n.feedbackStep3ScreenshotOverviewTitle),
      breadcrumbTitle:
          Text(context.l10n.feedbackStep3ScreenshotOverviewBreadcrumbTitle),
      description:
          Text(context.l10n.feedbackStep3ScreenshotOverviewDescription),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 48),
          SizedBox(
            width: double.infinity,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                TronButton(
                  color: context.theme.secondaryColor,
                  leadingIcon: Wirecons.arrow_left,
                  label: context.l10n.feedbackBackButton,
                  onTap: context.watchFeedbackModel.goToPreviousStep,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Wrap(
                    spacing: 20,
                    runSpacing: 10,
                    alignment: WrapAlignment.end,
                    verticalDirection: VerticalDirection.up,
                    runAlignment: WrapAlignment.spaceBetween,
                    children: [
                      TronButton(
                        color: context.theme.secondaryColor,
                        label: context
                            .l10n.feedbackStep3ScreenshotOverviewSkipButton,
                        trailingIcon: Wirecons.chevron_double_right,
                        onTap: () async {
                          if (!mounted) return;
                          await context.readFeedbackModel.skipScreenshot();
                        },
                      ),
                      TronButton(
                        color: context.theme.secondaryColor,
                        label: context.l10n
                            .feedbackStep3ScreenshotOverviewTakePhotoButton,
                        leadingIcon: Wirecons.camera,
                        onTap: () => _handlePick(ImageSource.camera),
                      ),
                      TronButton(
                        color: context.theme.secondaryColor,
                        label: context.l10n
                            .feedbackStep3ScreenshotOverviewPickFromGalleryButton,
                        leadingIcon: Wirecons.photograph,
                        onTap: () => _handlePick(ImageSource.gallery),
                      ),
                      TronButton(
                        label: context.l10n
                            .feedbackStep3ScreenshotOverviewAddScreenshotButton,
                        trailingIcon: Wirecons.arrow_right,
                        maxWidth: 250,
                        onTap: () => context.readFeedbackModel
                            .enterScreenshotCapturingMode(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _PhotoPickerError(message: _photoError),
        ],
      ),
    );
  }
}

class Step3WithGallery extends StatefulWidget {
  const Step3WithGallery({
    super.key,
  });

  @override
  State<Step3WithGallery> createState() => _Step3WithGalleryState();
}

class _Step3WithGalleryState extends State<Step3WithGallery> {
  String? _photoError;

  Future<void> _handlePick(ImageSource source) async {
    setState(() => _photoError = null);
    final ok = await _pickAndAttachPhoto(context, source);
    if (!mounted || ok) return;
    setState(() {
      _photoError = context
          .l10n.feedbackStep3ScreenshotOverviewPhotoPermissionDeniedMessage;
    });
  }

  @override
  Widget build(BuildContext context) {
    return StepPageScaffold(
      indicator: const FeedbackProgressIndicator(
        flowStatus: FeedbackFlowStatus.screenshotsOverview,
      ),
      currentStep: 2,
      totalSteps: 3,
      title: Text(context.l10n.feedbackStep3GalleryTitle),
      breadcrumbTitle: Text(context.l10n.feedbackStep3GalleryBreadcrumbTitle),
      description: Text(context.l10n.feedbackStep3GalleryDescription),
      discardLabel: Text(context.l10n.feedbackDiscardButton),
      discardConfirmLabel: Text(context.l10n.feedbackDiscardConfirmButton),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                child: SizedBox(
                  height: 200,
                  child: Center(
                    child: Row(
                      children: [
                        for (final att
                            in context.watchFeedbackModel.attachments)
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: constraints.maxWidth / 2.5,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.only(right: 16),
                              child: AttachmentPreview(attachment: att),
                            ),
                          ),
                        if (context.watchFeedbackModel.attachments.length < 3)
                          const NewAttachment(),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (context.watchFeedbackModel.attachments.length < 3)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      TronButton(
                        color: context.theme.secondaryColor,
                        label: context.l10n
                            .feedbackStep3ScreenshotOverviewTakePhotoButton,
                        leadingIcon: Wirecons.camera,
                        onTap: () => _handlePick(ImageSource.camera),
                      ),
                      TronButton(
                        color: context.theme.secondaryColor,
                        label: context.l10n
                            .feedbackStep3ScreenshotOverviewPickFromGalleryButton,
                        leadingIcon: Wirecons.photograph,
                        onTap: () => _handlePick(ImageSource.gallery),
                      ),
                    ],
                  ),
                ),
              if (_photoError != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _PhotoPickerError(message: _photoError),
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TronButton(
                    color: context.theme.secondaryColor,
                    leadingIcon: Wirecons.arrow_left,
                    label: context.l10n.feedbackBackButton,
                    onTap: context.readFeedbackModel.goToPreviousStep,
                  ),
                  TronButton(
                    label: context.l10n.feedbackNextButton,
                    trailingIcon: Wirecons.arrow_right,
                    onTap: context.readFeedbackModel.goToNextStep,
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class AttachmentPreview extends StatelessWidget {
  const AttachmentPreview({
    super.key,
    required this.attachment,
  });

  final PersistedAttachment attachment;

  @override
  Widget build(BuildContext context) {
    late Widget visual;

    if (attachment is Screenshot) {
      visual = Image.memory(
        attachment.file.data!,
        fit: BoxFit.contain,
      );
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        Elevation(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: visual,
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(4),
          child: TronButton(
            color: context.theme.primaryContainerColor,
            onTap: () {
              context.readFeedbackModel.deleteAttachment(attachment);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: TronIcon(
                Wirecons.trash,
                color: context.theme.textOnPrimaryContainerColor,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class NewAttachment extends StatelessWidget {
  const NewAttachment({super.key});

  @override
  Widget build(BuildContext context) {
    return Elevation(
      child: AspectRatio(
        aspectRatio: context.theme.windowSize.aspectRatio,
        child: AnimatedClickTarget(
          onTap: () {
            context.readFeedbackModel.enterScreenshotCapturingMode();
          },
          builder: (context, state, anims) {
            Color hoverColorAdjustment(Color color) {
              if (!state.hovered) {
                return color;
              }
              if (context.theme.brightness == Brightness.dark) {
                return color.lighten(0.02);
              } else {
                return color.darken(0.02);
              }
            }

            return Container(
              width: 160,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: Color.lerp(
                  context.theme.surfaceColor,
                  context.theme.surfaceColor.darken(0.05),
                  (anims.pressedAnim.value + anims.hoveredAnim.value) * 0.1,
                ),
              ),
              alignment: Alignment.center,
              child: AbsorbPointer(
                child: TronButton(
                  color: state.pressed
                      ? context.theme.primaryContainerColor
                          .let(hoverColorAdjustment)
                      : context.theme.primaryContainerColor
                          .let(hoverColorAdjustment),
                  onTap: () {
                    // nothing but style the button as if it is enabled.
                  },
                  child: TronIcon(
                    Wirecons.plus,
                    color: context.theme.textOnPrimaryContainerColor,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class Elevation extends StatelessWidget {
  const Elevation({super.key, this.child, this.elevation = 2});

  final Widget? child;
  final double elevation;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            // ignore: deprecated_member_use
            color: const Color(0xFF000000).withOpacity(0.04),
            offset: Offset(0, elevation),
            blurRadius: elevation,
          ),
          BoxShadow(
            // ignore: deprecated_member_use
            color: const Color(0xFF000000).withOpacity(0.10),
            offset: Offset(0, elevation * 3),
            blurRadius: elevation * 3,
          ),
        ],
      ),
      child: child,
    );
  }
}
