--- Types ---
export type CategoryUi = Frame & {
	Break: Frame,
	Title: TextLabel,
	ToggleExpansion: TextButton,
}
export type RadioButtonUi = Frame & {
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
export type SwitchUi = Frame & {
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
		Anchor: TextLabel,
		ListLayout: UIListLayout,
		NoSelections: TextLabel,
		Padding: UIPadding,
		SizeConstraint: UISizeConstraint,
		Target: TextLabel,
	},

	Settings: ScrollingFrame & {
		-- Categories
		AccessibilityOptions: CategoryUi,
		AlignAttachSetToOptions: CategoryUi,
		AlignmentMode: CategoryUi,
		AlignToOptions: CategoryUi,
		GeneralOptions: CategoryUi,
		SetToOptions: CategoryUi,

		-- Radio Buttons
		AlignInMultipleAxes: RadioButtonUi,
		AlignRootmostModel: RadioButtonUi,
		AlignTo: RadioButtonUi,
		AttachTo: RadioButtonUi,
		PlaceBetween: RadioButtonUi,
		ConstrainAligningToOneAxis: RadioButtonUi,
		PartOnly: RadioButtonUi,
		ResizeTo: RadioButtonUi,
		SelectMethodAfterAlignment: RadioButtonUi,
		SetPositionOrientationAndSize: RadioButtonUi,
		SetPositionAndOrientation: RadioButtonUi,
		SetPositionOnly: RadioButtonUi,
		SetOrientationOnly: RadioButtonUi,
		SetSizeOnly: RadioButtonUi,
		SetTo: RadioButtonUi,

		-- Switches
		ContrastPartHighlighting: SwitchUi,
		LockedAnchorPartsSelectable: SwitchUi,
		LockedTargetPartsSelectable: SwitchUi,
		NoCanCollideQueryAnchorSelectable: SwitchUi,
		NoCanCollideQueryTargetSelectable: SwitchUi,
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

--- Widget Types ---
return true
