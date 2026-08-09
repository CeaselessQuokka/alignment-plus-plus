-- Types --
-- Categories and setting rows are buttons rather than frames so that the whole row is clickable, not just the
-- small control at the end of it.
export type CategoryUi = TextButton & {
	Break: Frame,
	Title: TextLabel,
	ToggleExpansion: TextButton,
}
export type RadioButtonUi = TextButton & {
	HelpButton: ImageButton & {
		Corner: UICorner,
		QuestionMark: TextLabel,
	},

	RadioButton: ImageButton & {
		Tick: Frame & {
			UICorner: UICorner,
			UIStroke: UIStroke,
		},

		Padding: UIPadding,
		UICorner: UICorner,
	},

	SettingName: TextLabel,
}
export type SwitchUi = TextButton & {
	HelpButton: ImageButton & {
		Corner: UICorner,
		QuestionMark: TextLabel,
	},

	SwitchButton: ImageButton & {
		Switch: Frame & {
			UICorner: UICorner,
			UIStroke: UIStroke,
		},

		Padding: UIPadding,
		UICorner: UICorner,
	},

	SettingName: TextLabel,
}
export type Ui = Frame & {
	Selection: Frame & {
		Prompt: TextLabel,
		Slot1: TextLabel,
		Slot2: TextLabel,
		Slot3: TextLabel,
		Hint: TextLabel,

		ListLayout: UIListLayout,
		Padding: UIPadding,
		SizeConstraint: UISizeConstraint,
	},

	Settings: ScrollingFrame & {
		-- Categories
		ModeOptions: CategoryUi,
		AlignToOptions: CategoryUi,
		SetToOptions: CategoryUi,
		SubjectOptions: CategoryUi,
		SelectionOptions: CategoryUi,
		GeneralOptions: CategoryUi,

		-- Modes
		AlignTo: RadioButtonUi,
		AttachTo: RadioButtonUi,
		PointAt: RadioButtonUi,
		ResizeTo: RadioButtonUi,
		SetTo: RadioButtonUi,
		PlaceBetween: RadioButtonUi,

		-- Align To options
		AlignAlongNormal: RadioButtonUi,
		AlignOnNearestAxis: RadioButtonUi,
		AlignChooseInViewport: RadioButtonUi,

		-- Set To options
		SetPositionAndOrientation: RadioButtonUi,
		SetPositionOrientationAndSize: RadioButtonUi,
		SetPositionOnly: RadioButtonUi,
		SetOrientationOnly: RadioButtonUi,
		SetSizeOnly: RadioButtonUi,

		-- What a manipulation moves
		SubjectAutoModel: RadioButtonUi,
		SubjectRootmostModel: RadioButtonUi,
		SubjectPartOnly: RadioButtonUi,

		-- Switches
		AdvancedMode: SwitchUi,
		ContrastPartHighlighting: SwitchUi,
		KeepTargetAfterAction: SwitchUi,
		LockedAnchorPartsSelectable: SwitchUi,
		LockedTargetPartsSelectable: SwitchUi,
		NoCanCollideQueryAnchorSelectable: SwitchUi,
		NoCanCollideQueryTargetSelectable: SwitchUi,
		PlaySounds: SwitchUi,
		RespectPartPivot: SwitchUi,

		ListLayout: UIListLayout,
		Padding: UIPadding,
	},

	Tooltip: Frame & {
		Scroller: ScrollingFrame & {
			Tip: TextLabel & {
				TextConstraint: UITextSizeConstraint,
			},

			Padding: UIPadding,
		},

		Close: TextButton & {
			UICorner: UICorner,
		},
		SizeConstraint: UISizeConstraint,
	},

	ListLayout: UIListLayout,
	Padding: UIPadding,
}

-- Widget Types --
return true
