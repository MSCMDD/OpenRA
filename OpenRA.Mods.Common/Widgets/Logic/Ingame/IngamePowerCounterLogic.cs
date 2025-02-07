#region Copyright & License Information
/*
 * Copyright (c) The OpenRA Developers and Contributors
 * This file is part of OpenRA, which is free software. It is made
 * available to you under the terms of the GNU General Public License
 * as published by the Free Software Foundation, either version 3 of
 * the License, or (at your option) any later version. For more
 * information, see COPYING.
 */
#endregion

using System.Globalization;
using OpenRA.Mods.Common.Traits;
using OpenRA.Primitives;
using OpenRA.Widgets;

namespace OpenRA.Mods.Common.Widgets.Logic
{
	public class IngamePowerCounterLogic : ChromeLogic
	{
		[FluentReference("usage", "capacity")]
		const string PowerUsage = "label-power-usage";

		[FluentReference]
		const string Infinite = "label-infinite-power";

		[ObjectCreator.UseCtor]
		public IngamePowerCounterLogic(Widget widget, ModData modData, World world)
		{
			var developerMode = world.LocalPlayer.PlayerActor.Trait<DeveloperMode>();

			var powerManager = world.LocalPlayer.PlayerActor.Trait<PowerManager>();
			var power = widget.Get<LabelWithTooltipWidget>("POWER");
			var powerIcon = widget.Get<ImageWidget>("POWER_ICON");
			var unlimitedCapacity = FluentProvider.GetMessage(Infinite);

			powerIcon.GetImageName = () => powerManager.ExcessPower < 0 ? "power-critical" : "power-normal";
			power.GetColor = () => powerManager.ExcessPower < 0 ? Color.Red : Color.White;
			power.GetText = () => developerMode.UnlimitedPower ? unlimitedCapacity : powerManager.ExcessPower.ToString(NumberFormatInfo.CurrentInfo);

			var tooltipTextCached = new CachedTransform<(int, int?), string>(((int Usage, int? Capacity) args) =>
			{
				var capacity = args.Capacity == null ? unlimitedCapacity : args.Capacity.Value.ToString(NumberFormatInfo.CurrentInfo);
				return FluentProvider.GetMessage(PowerUsage,
					"usage", args.Usage.ToString(NumberFormatInfo.CurrentInfo),
					"capacity", capacity);
			});

			power.GetTooltipText = () =>
			{
				var capacity = developerMode.UnlimitedPower ? (int?)null : powerManager.PowerProvided;

				return tooltipTextCached.Update((powerManager.PowerDrained, capacity));
			};
		}
	}
}
