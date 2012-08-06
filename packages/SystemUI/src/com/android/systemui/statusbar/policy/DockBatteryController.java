/*
 * Copyright (C) 2010 The Android Open Source Project
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package com.android.systemui.statusbar.policy;

import java.util.ArrayList;

import android.content.BroadcastReceiver;
import android.graphics.Color;
import android.text.Spannable;
import android.text.SpannableStringBuilder;
import android.text.style.RelativeSizeSpan;
import android.text.style.CharacterStyle;
import android.content.ContentResolver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.database.ContentObserver;
import android.os.BatteryManager;
import android.os.Handler;
import android.provider.Settings;
import android.util.AttributeSet;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.TextView;

import com.android.systemui.R;

public class DockBatteryController extends BroadcastReceiver {
    private static final String TAG = "StatusBar.DockBatteryController";

    private Context mContext;
    private ArrayList<ImageView> mIconViews = new ArrayList<ImageView>();
    private ArrayList<TextView> mLabelViews = new ArrayList<TextView>();

    private ImageView mBatteryIcon;
    private TextView mBatteryText;
    private TextView mBatteryCenterText;
    private ViewGroup mBatteryGroup;
    private TextView mBatteryTextOnly;

    private static int mBatteryStyle;

    private int mLevel = -1;
    private boolean mPlugged = false;
    private boolean mDockStatus = false;
    private boolean mHasDockBattery;
    private int state;

    private static final boolean DBG = true;

    public static final int STYLE_ICON_ONLY = 0;
    public static final int STYLE_TEXT_ONLY = 1;
    public static final int STYLE_ICON_TEXT = 2;
    public static final int STYLE_ICON_CENTERED_TEXT = 3;
    public static final int STYLE_ICON_CIRCLE = 4;
    public static final int STYLE_HIDE = 5;

    public DockBatteryController(Context context, AttributeSet attrs) {
        super(context, attrs);
        mContext = context;

    }

    @Override
    protected void onAttachedToWindow() {
        super.onAttachedToWindow();
        init();
        mBatteryGroup = (ViewGroup) findViewById(R.id.dock_combo);
        mBatteryIcon = (ImageView) findViewById(R.id.dock_battery);
        mBatteryText = (TextView) findViewById(R.id.dock_text);
        mBatteryCenterText = (TextView) findViewById(R.id.dock_text_center);
        mBatteryTextOnly = (TextView) findViewById(R.id.dock_text_only);
        addIconView(mBatteryIcon);

        mHasDockBattery = mContext.getResources().getBoolean(
                com.android.internal.R.bool.config_hasDockBattery);

        SettingsObserver settingsObserver = new SettingsObserver(new Handler());
        settingsObserver.observe();
        updateSettings(); // to initialize values

    }

    private void init() {
        IntentFilter filter = new IntentFilter();
        filter.addAction(Intent.ACTION_BATTERY_CHANGED);
        filter.addAction(Intent.ACTION_DOCK_EVENT);
        mContext.registerReceiver(mBatteryBroadcastReceiver, filter);
    private static final int BATTERY_STYLE_NORMAL  = 0;
    private static final int BATTERY_STYLE_TEXT    = 1;
    private static final int BATTERY_STYLE_GONE    = 2;

    private static final int BATTERY_ICON_STYLE_NORMAL      = R.drawable.stat_sys_kb_battery;
    private static final int BATTERY_ICON_STYLE_CHARGE      = R.drawable.stat_sys_kb_battery_charge;

    private boolean mDockStatus = false;
    private boolean mDockCharging = false;
    private int mBatteryStyle;
    private int mBatteryIcon = BATTERY_ICON_STYLE_NORMAL;

    private static final int BATTERY_TEXT_STYLE_NORMAL  = R.string.status_bar_settings_battery_meter_format;
    private static final int BATTERY_TEXT_STYLE_MIN     = R.string.status_bar_settings_battery_meter_min_format;

    Handler mHandler;

    class SettingsObserver extends ContentObserver {
        SettingsObserver(Handler handler) {
            super(handler);
        }

        void observe() {
            ContentResolver resolver = mContext.getContentResolver();
            resolver.registerContentObserver(Settings.System.getUriFor(
                    Settings.System.STATUS_BAR_BATTERY), false, this);
        }

        @Override public void onChange(boolean selfChange) {
            updateSettings();
        }
    }

    public DockBatteryController(Context context) {
        mContext = context;
        mHandler = new Handler();

        SettingsObserver settingsObserver = new SettingsObserver(mHandler);
        settingsObserver.observe();
        updateSettings();

        IntentFilter filter = new IntentFilter();
        filter.addAction(Intent.ACTION_BATTERY_CHANGED);
        context.registerReceiver(this, filter);
    }

    public void addIconView(ImageView v) {
        mIconViews.add(v);
    }

    public void addLabelView(TextView v) {
        mLabelViews.add(v);
    }

    private BroadcastReceiver mBatteryBroadcastReceiver = new BroadcastReceiver() {

        @Override
        public void onReceive(Context context, Intent intent) {
            final String action = intent.getAction();

            /* if we got a dock event get the dock status */
            if (action.equals(Intent.ACTION_BATTERY_CHANGED) || action.equals(Intent.ACTION_DOCK_EVENT)) {
                mDockStatus = intent.getIntExtra(
                    BatteryManager.EXTRA_DOCK_STATUS, 0) != BatteryManager.DOCK_STATE_UNDOCKED;

                if (action.equals(Intent.ACTION_BATTERY_CHANGED) ||
                    (action.equals(Intent.ACTION_DOCK_EVENT) && mDockStatus)) {

                    mLevel = intent.getIntExtra(
                            BatteryManager.EXTRA_DOCK_LEVEL, 0);
                    mPlugged = intent.getIntExtra(
                            BatteryManager.EXTRA_DOCK_STATUS, 0) == BatteryManager.DOCK_STATE_CHARGING;
                }

                if (action.equals(Intent.ACTION_BATTERY_CHANGED)) {
                    setBatteryIcon(mLevel, mPlugged, mDockStatus);
                } else if (action.equals(Intent.ACTION_DOCK_EVENT)) {
                    state = intent.getIntExtra(Intent.EXTRA_DOCK_STATE,
                            Intent.EXTRA_DOCK_STATE_UNDOCKED);

                    updateSettings();
                }
            }
        }
    };

    private void setBatteryIcon(int level, boolean plugged, boolean dockstatus) {
        mLevel = level;
        mPlugged = plugged;
        mDockStatus = dockstatus;
        int mShow = View.GONE;
        boolean mText = false;

        ContentResolver cr = mContext.getContentResolver();
        mBatteryStyle = Settings.System.getInt(cr,
                Settings.System.STATUSBAR_BATTERY_ICON, 0);
        int icon;
        if (mBatteryStyle == STYLE_ICON_CIRCLE) {
            mShow = mDockStatus ? (View.VISIBLE) : (View.GONE);
            icon = plugged ? R.drawable.stat_sys_battery_charge_circle
                    : R.drawable.stat_sys_battery_circle;
        } else {
            mShow = mDockStatus ? (View.VISIBLE) : (View.GONE);
            icon = plugged ? R.drawable.stat_sys_kb_battery_charge
                    : R.drawable.stat_sys_kb_battery;
        }
        int N = mIconViews.size();
        for (int i = 0; i < N; i++) {
            ImageView v = mIconViews.get(i);
            v.setImageResource(icon);
            v.setImageLevel(level);
            v.setContentDescription(mContext.getString(
                    R.string.accessibility_battery_level, level));
        }
        N = mLabelViews.size();
        for (int i = 0; i < N; i++) {
            TextView v = mLabelViews.get(i);
            v.setText(mContext.getString(
                    R.string.status_bar_settings_battery_meter_format, level));
        }

        // do my stuff here
        if (mBatteryGroup != null) {
            mBatteryText.setText(Integer.toString(level));
            mBatteryCenterText.setText(Integer.toString(level));
            mBatteryTextOnly.setText(Integer.toString(level));
            SpannableStringBuilder formatted = new SpannableStringBuilder(
                    Integer.toString(level) + "%");
            CharacterStyle style = new RelativeSizeSpan(0.7f); // beautiful
                                                               // formatting
            if (level < 10) { // level < 10, 2nd char is %
                formatted.setSpan(style, 1, 2,
                        Spannable.SPAN_EXCLUSIVE_INCLUSIVE);
            } else if (level < 100) { // level 10-99, 3rd char is %
                formatted.setSpan(style, 2, 3,
                        Spannable.SPAN_EXCLUSIVE_INCLUSIVE);
            } else { // level 100, 4th char is %
                formatted.setSpan(style, 3, 4,
                        Spannable.SPAN_EXCLUSIVE_INCLUSIVE);
            }
            mBatteryTextOnly.setText(formatted);
            if (plugged) { // colors hardcoded by now, maybe colorpicker can be
                           // added if needed
                mBatteryTextOnly.setTextColor(Color.GREEN);
            } else if (level < 16) {
                mBatteryTextOnly.setTextColor(Color.RED);
            } else {
                mBatteryTextOnly.setTextColor(0xFF33B5E5);
            }
        }
    }

    class SettingsObserver extends ContentObserver {
        SettingsObserver(Handler handler) {
            super(handler);
        }

        void observe() {
            ContentResolver resolver = mContext.getContentResolver();
            resolver.registerContentObserver(Settings.System
                    .getUriFor(Settings.System.STATUSBAR_BATTERY_ICON), false,
                    this);
            resolver.registerContentObserver(
                    Settings.System.getUriFor(Settings.System.STATUSBAR_FONT_SIZE), false, this);
        }

        @Override
        public void onChange(boolean selfChange) {
            updateSettings();
    public void onReceive(Context context, Intent intent) {
        final String action = intent.getAction();
        if (action.equals(Intent.ACTION_BATTERY_CHANGED)) {
            final int level = intent.getIntExtra(BatteryManager.EXTRA_DOCK_LEVEL, 0);
            mDockCharging = intent.getIntExtra(BatteryManager.EXTRA_DOCK_STATUS, 0) == BatteryManager.DOCK_STATE_CHARGING;
            mDockStatus = intent.getIntExtra(BatteryManager.EXTRA_DOCK_STATUS, 0) != BatteryManager.DOCK_STATE_UNDOCKED;

            int N = mIconViews.size();
            for (int i=0; i<N; i++) {
                ImageView v = mIconViews.get(i);
                v.setImageLevel(level);
                v.setContentDescription(mContext.getString(R.string.accessibility_battery_level,
                        level));
            }
            N = mLabelViews.size();
            for (int i=0; i<N; i++) {
                TextView v = mLabelViews.get(i);
                v.setText(mContext.getString(BATTERY_TEXT_STYLE_MIN,
                        level));
            }
            updateBattery();
        }
    }

    private void updateBattery() {
        int mIcon = View.GONE;
        int mText = View.GONE;
        int mIconStyle = BATTERY_ICON_STYLE_NORMAL;

        if (mBatteryStyle == 0) {
            mIcon = mDockStatus ? (View.VISIBLE) : (View.GONE);
            mIconStyle = mDockCharging ? BATTERY_ICON_STYLE_CHARGE
                    : BATTERY_ICON_STYLE_NORMAL;
        } else if(mBatteryStyle == 1){
            mIcon = mDockStatus ? (View.VISIBLE) : (View.GONE);
            mText = mDockStatus ? (View.VISIBLE) : (View.GONE);
            mIconStyle = mDockCharging ? BATTERY_ICON_STYLE_CHARGE
                    : BATTERY_ICON_STYLE_NORMAL;
        }

        int N = mIconViews.size();
        for (int i=0; i<N; i++) {
            ImageView v = mIconViews.get(i);
            v.setVisibility(mIcon);
            v.setImageResource(mIconStyle);
        }
        N = mLabelViews.size();
        for (int i=0; i<N; i++) {
            TextView v = mLabelViews.get(i);
            v.setVisibility(mText);
        }
    }

    private void updateSettings() {
        //Slog.i(TAG, "updated settings values");
        ContentResolver cr = mContext.getContentResolver();
        mBatteryStyle = Settings.System.getInt(cr,
                Settings.System.STATUSBAR_BATTERY_ICON, 0);

        if (mHasDockBattery && mDockStatus && state != Intent.EXTRA_DOCK_STATE_UNDOCKED) {
            switch (mBatteryStyle) {
                case STYLE_ICON_ONLY:
                    mBatteryCenterText.setVisibility(View.GONE);
                    mBatteryText.setVisibility(View.GONE);
                    mBatteryIcon.setVisibility(View.VISIBLE);
                    mBatteryTextOnly.setVisibility(View.GONE);
                    setVisibility(View.VISIBLE);
                    break;
                case STYLE_TEXT_ONLY:
                    mBatteryText.setVisibility(View.GONE);
                    mBatteryCenterText.setVisibility(View.GONE);
                    mBatteryIcon.setVisibility(View.GONE);
                    mBatteryTextOnly.setVisibility(View.VISIBLE);
                    setVisibility(View.VISIBLE);
                    break;
                case STYLE_ICON_TEXT:
                    mBatteryText.setVisibility(View.VISIBLE);
                    mBatteryCenterText.setVisibility(View.GONE);
                    mBatteryIcon.setVisibility(View.VISIBLE);
                    mBatteryTextOnly.setVisibility(View.GONE);
                    setVisibility(View.VISIBLE);
                    break;
                case STYLE_ICON_CENTERED_TEXT:
                    mBatteryText.setVisibility(View.GONE);
                    mBatteryCenterText.setVisibility(View.VISIBLE);
                    mBatteryIcon.setVisibility(View.VISIBLE);
                    mBatteryTextOnly.setVisibility(View.GONE);
                    setVisibility(View.VISIBLE);
                    break;
                case STYLE_HIDE:
                    mBatteryText.setVisibility(View.GONE);
                    mBatteryCenterText.setVisibility(View.GONE);
                    mBatteryIcon.setVisibility(View.GONE);
                    mBatteryTextOnly.setVisibility(View.GONE);
                    setVisibility(View.GONE);
                    break;
                case STYLE_ICON_CIRCLE:
                    mBatteryText.setVisibility(View.GONE);
                    mBatteryCenterText.setVisibility(View.GONE);
                    mBatteryIcon.setVisibility(View.VISIBLE);
                    mBatteryTextOnly.setVisibility(View.GONE);
                    setVisibility(View.VISIBLE);
                    break;
                default:
                    mBatteryText.setVisibility(View.GONE);
                    mBatteryCenterText.setVisibility(View.GONE);
                    mBatteryIcon.setVisibility(View.VISIBLE);
                    mBatteryTextOnly.setVisibility(View.GONE);
                    setVisibility(View.VISIBLE);
                    break;
            }
        } else {
            mBatteryText.setVisibility(View.GONE);
            mBatteryCenterText.setVisibility(View.GONE);
            mBatteryIcon.setVisibility(View.GONE);
            mBatteryTextOnly.setVisibility(View.GONE);
            setVisibility(View.GONE);
        }


        setBatteryIcon(mLevel, mPlugged, mDockStatus);

        int fontSize = Settings.System.getInt(cr,
                Settings.System.STATUSBAR_FONT_SIZE, 16);
        if (mBatteryTextOnly != null)
             mBatteryTextOnly.setTextSize(fontSize);

    }
}
