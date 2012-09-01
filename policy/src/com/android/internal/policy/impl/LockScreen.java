/*
 * Copyright (C) 2008 The Android Open Source Project
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

package com.android.internal.policy.impl;

import android.app.ActivityManagerNative;
import android.app.SearchManager;
import android.content.ActivityNotFoundException;
import android.content.ComponentName;
import android.content.ContentResolver;
import android.content.Context;
import android.content.Intent;
import android.content.pm.ActivityInfo;
import android.content.pm.PackageManager;
import android.content.pm.PackageManager.NameNotFoundException;
import android.content.res.ColorStateList;
import android.content.res.Configuration;
import android.content.res.Resources;
import android.content.res.Resources.NotFoundException;
import android.database.ContentObserver;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.drawable.BitmapDrawable;
import android.graphics.drawable.Drawable;
import android.graphics.drawable.InsetDrawable;
import android.graphics.drawable.LayerDrawable;
import android.graphics.drawable.StateListDrawable;
import android.media.AudioManager;
import android.net.Uri;
import android.os.Handler;
import android.os.RemoteException;
import android.provider.MediaStore;
import android.provider.Settings;
import android.util.Log;
import android.util.Slog;
import android.util.TypedValue;
import android.view.KeyEvent;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.view.ViewParent;
import android.widget.DigitalClock;
import android.widget.FrameLayout;
import android.widget.ImageView;
import android.widget.ImageView.ScaleType;
import android.widget.LinearLayout;
import android.widget.RelativeLayout;
import android.widget.TextView;

import com.android.internal.R;
import com.android.internal.policy.impl.KeyguardUpdateMonitor.InfoCallbackImpl;
import com.android.internal.policy.impl.KeyguardUpdateMonitor.SimStateCallback;
import com.android.internal.telephony.IccCard.State;
import com.android.internal.widget.LockPatternUtils;
import com.android.internal.widget.SlidingTab;
import com.android.internal.widget.WaveView;
import com.android.internal.widget.multiwaveview.GlowPadView;
import com.android.internal.widget.multiwaveview.MultiWaveView;
import com.android.internal.widget.multiwaveview.TargetDrawable;

import java.io.File;
import java.net.URISyntaxException;
import java.util.ArrayList;

/**
 * The screen within {@link LockPatternKeyguardView} that shows general information about the device
 * depending on its state, and how to get past it, as applicable.
 */
class LockScreen extends LinearLayout implements KeyguardScreen {

    private static final int ON_RESUME_PING_DELAY = 500; // delay first ping until the screen is on
    private static final boolean DBG = false;
    private static final boolean DEBUG = DBG;
    private static final String TAG = "LockScreen";
    private static final int WAIT_FOR_ANIMATION_TIMEOUT = 0;
    private static final int STAY_ON_WHILE_GRABBED_TIMEOUT = 30000;
    private static final String ASSIST_ICON_METADATA_NAME =
            "com.android.systemui.action_assist_icon";
    
    public static final int LAYOUT_STOCK = 2;
    public static final int LAYOUT_AOSP = 1;
    public static final int LAYOUT_HONEY = 0;
    public static final int LAYOUT_TRI = 3;
    public static final int LAYOUT_QUAD = 4;
    public static final int LAYOUT_HEPTA = 5;
    public static final int LAYOUT_HEXA = 6;
    public static final int LAYOUT_SEPTA = 7;
    public static final int LAYOUT_OCTO = 8;
    
    private boolean mLockscreen4Tab = false || (Settings.System.getInt(
			mContext.getContentResolver(),
			Settings.System.LOCKSCREEN_4TAB, 0) == 1);

    private int mLockscreenTargets = LAYOUT_STOCK;
    
    private LockPatternUtils mLockPatternUtils;
    private KeyguardUpdateMonitor mUpdateMonitor;
    private KeyguardScreenCallback mCallback;
    private SettingsObserver mSettingsObserver;

    // set to 'true' to show the ring/silence target when camera isn't available
    private boolean mEnableRingSilenceFallback = false;

    // current configuration state of keyboard and display
    private int mCreationOrientation;

    private boolean mSilentMode;
    private AudioManager mAudioManager;
    private boolean mEnableMenuKeyInLockScreen;

    private KeyguardStatusViewManager mStatusViewManager;
    private UnlockWidgetCommonMethods mUnlockWidgetMethods;
    private View mUnlockWidget;
    private View mUnlockWidget2;
    
    private TextView mCarrier;
    private DigitalClock mDigitalClock;

    ArrayList<Target> lockTargets = new ArrayList<Target>();
    
    private String mCustomAppActivity = (Settings.System.getString(mContext.getContentResolver(),
            Settings.System.LOCKSCREEN_CUSTOM_APP_ACTIVITY));  
    
    private boolean mCameraDisabled;
    private boolean mSearchDisabled;

    InfoCallbackImpl mInfoCallback = new InfoCallbackImpl() {

        @Override
        public void onRingerModeChanged(int state) {
            boolean silent = AudioManager.RINGER_MODE_NORMAL != state;
            if (silent != mSilentMode) {
                mSilentMode = silent;
                mUnlockWidgetMethods.updateResources();
            }
        }

        @Override
        public void onDevicePolicyManagerStateChanged() {
            updateTargets();
        }

    };

    SimStateCallback mSimStateCallback = new SimStateCallback() {
        public void onSimStateChanged(State simState) {
            updateTargets();
        }
    };

    private interface UnlockWidgetCommonMethods {
        // Update resources based on phone state
        public void updateResources();

        // Get the view associated with this widget
        public View getView();

        // Reset the view
        public void reset(boolean animate);

        // Animate the widget if it supports ping()
        public void ping();

        // Enable or disable a target. ResourceId is the id of the *drawable* associated with the
        // target.
        public void setEnabled(int resourceId, boolean enabled);

        // Get the target position for the given resource. Returns -1 if not found.
        public int getTargetPosition(int resourceId);

        // Clean up when this widget is going away
        public void cleanUp();
    }

    class SlidingTabMethods implements SlidingTab.OnTriggerListener, UnlockWidgetCommonMethods {
        private final SlidingTab mSlidingTab;

        SlidingTabMethods(SlidingTab slidingTab) {
            mSlidingTab = slidingTab;
        }

        public void updateResources() {
            boolean vibe = mSilentMode
                    && (mAudioManager.getRingerMode() == AudioManager.RINGER_MODE_VIBRATE);

            mSlidingTab.setRightTabResources(
                    mSilentMode ? (vibe ? R.drawable.ic_jog_dial_vibrate_on
                            : R.drawable.ic_jog_dial_sound_off)
                            : R.drawable.ic_jog_dial_sound_on,
                    mSilentMode ? R.drawable.jog_tab_target_yellow
                            : R.drawable.jog_tab_target_gray,
                    mSilentMode ? R.drawable.jog_tab_bar_right_sound_on
                            : R.drawable.jog_tab_bar_right_sound_off,
                    mSilentMode ? R.drawable.jog_tab_right_sound_on
                            : R.drawable.jog_tab_right_sound_off);
        }

        /** {@inheritDoc} */
        public void onTrigger(View v, int whichHandle) {
            if (whichHandle == SlidingTab.OnTriggerListener.LEFT_HANDLE) {
                mCallback.goToUnlockScreen();
            } else if (whichHandle == SlidingTab.OnTriggerListener.RIGHT_HANDLE) {
                toggleRingMode();
                mUnlockWidgetMethods.updateResources();
                mCallback.pokeWakelock();
            }
        }

        /** {@inheritDoc} */
        public void onGrabbedStateChange(View v, int grabbedState) {
            if (grabbedState == SlidingTab.OnTriggerListener.RIGHT_HANDLE) {
                mSilentMode = isSilentMode();
                mSlidingTab.setRightHintText(mSilentMode ? R.string.lockscreen_sound_on_label
                        : R.string.lockscreen_sound_off_label);
            }
            // Don't poke the wake lock when returning to a state where the handle is
            // not grabbed since that can happen when the system (instead of the user)
            // cancels the grab.
            if (grabbedState != SlidingTab.OnTriggerListener.NO_HANDLE) {
                mCallback.pokeWakelock();
            }
        }

        public View getView() {
            return mSlidingTab;
        }

        public void reset(boolean animate) {
            mSlidingTab.reset(animate);
        }

        public void ping() {
        }

        public void setEnabled(int resourceId, boolean enabled) {
            // Not used
        }

        public int getTargetPosition(int resourceId) {
            return -1; // Not supported
        }

        public void cleanUp() {
            mSlidingTab.setOnTriggerListener(null);
        }
    }
    
    class SlidingTabMethods2 implements SlidingTab.OnTriggerListener, UnlockWidgetCommonMethods {
        private final SlidingTab mSlidingTab2;

        SlidingTabMethods2(SlidingTab slidingTab) {
            mSlidingTab2 = slidingTab;
        }

        public void updateResources() {
        }

        /** {@inheritDoc} */
		public void onTrigger(View v, int whichHandle) {
			if (whichHandle == SlidingTab.OnTriggerListener.LEFT_HANDLE) {
				Intent callIntent = new Intent(Intent.ACTION_DIAL);
				callIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
				getContext().startActivity(callIntent);
				mCallback.goToUnlockScreen();
			} else if (whichHandle == SlidingTab.OnTriggerListener.RIGHT_HANDLE) {
				Intent intent = new Intent(Intent.ACTION_MAIN);
                intent.addCategory(Intent.CATEGORY_LAUNCHER);
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK
                        | Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED);
                intent.setClassName("com.android.mms", "com.android.mms.ui.ConversationList");
                mContext.startActivity(intent);
                mCallback.goToUnlockScreen();
				if (mCustomAppActivity != null) {
					runActivity(mCustomAppActivity);
				}
			}
		}

        /** {@inheritDoc} */
		public void onGrabbedStateChange(View v, int grabbedState) {
			mCallback.pokeWakelock();
		}

        public View getView() {
            return mSlidingTab2;
        }

        public void reset(boolean animate) {
            mSlidingTab2.reset(animate);
        }

        public void ping() {
        }

        @Override
        public void setEnabled(int resourceId, boolean enabled) {
            // TODO Auto-generated method stub
            
        }

        @Override
        public int getTargetPosition(int resourceId) {
            // TODO Auto-generated method stub
            return 0;
        }

        @Override
        public void cleanUp() {
            // TODO Auto-generated method stub
            
        }
    }

    class WaveViewMethods implements WaveView.OnTriggerListener, UnlockWidgetCommonMethods {

        private final WaveView mWaveView;

        WaveViewMethods(WaveView waveView) {
            mWaveView = waveView;
        }

        /** {@inheritDoc} */
        public void onTrigger(View v, int whichHandle) {
            if (whichHandle == WaveView.OnTriggerListener.CENTER_HANDLE) {
                requestUnlockScreen();
            }
        }

        /** {@inheritDoc} */
        public void onGrabbedStateChange(View v, int grabbedState) {
            // Don't poke the wake lock when returning to a state where the handle is
            // not grabbed since that can happen when the system (instead of the user)
            // cancels the grab.
            if (grabbedState == WaveView.OnTriggerListener.CENTER_HANDLE) {
                mCallback.pokeWakelock(STAY_ON_WHILE_GRABBED_TIMEOUT);
            }
        }

        public void updateResources() {
        }

        public View getView() {
            return mWaveView;
        }

        public void reset(boolean animate) {
            mWaveView.reset();
        }

        public void ping() {
        }
        public void setEnabled(int resourceId, boolean enabled) {
            // Not used
        }
        public int getTargetPosition(int resourceId) {
            return -1; // Not supported
        }
        public void cleanUp() {
            mWaveView.setOnTriggerListener(null);
        }
    }

    class MultiWaveViewMethods implements MultiWaveView.OnTriggerListener,
    UnlockWidgetCommonMethods {

        private final MultiWaveView mMultiWaveView;
        
        MultiWaveViewMethods(MultiWaveView multiWaveView) {
            mMultiWaveView = multiWaveView;
            final boolean cameraDisabled = mLockPatternUtils.getDevicePolicyManager()
                    .getCameraDisabled(null);
            if (cameraDisabled) {
                Log.v(TAG, "Camera disabled by Device Policy");
                mCameraDisabled = true;
            } else {
                // Camera is enabled if resource is initially defined for MultiWaveView
                // in the lockscreen layout file
                mCameraDisabled = mMultiWaveView.getTargetResourceId()
                        != R.array.lockscreen_targets_with_camera;
            }
        }
        
        public void updateResources() {
            boolean isLandscape = (mCreationOrientation == Configuration
                    .ORIENTATION_LANDSCAPE);
        
            targetController.setLandscape(isLandscape);
            targetController.setupTargets();
        
            mMultiWaveView.setTargetResources(targetController.getDrawables());
        }
        
        public void onGrabbed(View v, int handle) {
        
        }
        
        public void onReleased(View v, int handle) {
        
        }
        
        public void onTrigger(View v, int target) {
            if (DBG)
                Log.v(TAG, "onTrigger: target = " + target);
            if (DBG)
                Log.v(TAG, "onTrigger: Orientation = " + mCreationOrientation);
            targetController.getTarget(target).doAction();
        }
        
        public void onGrabbedStateChange(View v, int handle) {
            // Don't poke the wake lock when returning to a state where the handle is
            // not grabbed since that can happen when the system (instead of the user)
            // cancels the grab.
            if (handle != MultiWaveView.OnTriggerListener.NO_HANDLE) {
                mCallback.pokeWakelock();
            }
        }
        
        public View getView() {
            return mMultiWaveView;
        }
        
        public void reset(boolean animate) {
            mMultiWaveView.reset(animate);
        }
        
        public void ping() {
            mMultiWaveView.ping();
        }

        @Override
        public void setEnabled(int resourceId, boolean enabled) {
            // TODO Auto-generated method stub
            
        }

        @Override
        public int getTargetPosition(int resourceId) {
            // TODO Auto-generated method stub
            return 0;
        }

        @Override
        public void cleanUp() {
            // TODO Auto-generated method stub
            
        }

        @Override
        public void onFinishFinalAnimation() {
            // TODO Auto-generated method stub
            
        }
    }

    class GlowPadViewMethods implements GlowPadView.OnTriggerListener,
    UnlockWidgetCommonMethods {
        private final GlowPadView mGlowPadView;
        private String[] mStoredTargets;
        private int mTargetOffset;
        private boolean mIsScreenLarge;
        
        GlowPadViewMethods(GlowPadView glowPadView) {
            mGlowPadView = glowPadView;
        }
        
        public boolean isScreenLarge() {
            final int screenSize = Resources.getSystem().getConfiguration().screenLayout &
                    Configuration.SCREENLAYOUT_SIZE_MASK;
            boolean isScreenLarge = screenSize == Configuration.SCREENLAYOUT_SIZE_LARGE ||
                    screenSize == Configuration.SCREENLAYOUT_SIZE_XLARGE;
            return isScreenLarge;
        }
        
        private StateListDrawable getLayeredDrawable(Drawable back, Drawable front, int inset, boolean frontBlank) {
            Resources res = getResources();
            InsetDrawable[] inactivelayer = new InsetDrawable[2];
            InsetDrawable[] activelayer = new InsetDrawable[2];
            inactivelayer[0] = new InsetDrawable(res.getDrawable(com.android.internal.R.drawable.ic_lockscreen_lock_pressed), 0, 0, 0, 0);
            inactivelayer[1] = new InsetDrawable(front, inset, inset, inset, inset);
            activelayer[0] = new InsetDrawable(back, 0, 0, 0, 0);
            activelayer[1] = new InsetDrawable(frontBlank ? res.getDrawable(android.R.color.transparent) : front, inset, inset, inset, inset);
            StateListDrawable states = new StateListDrawable();
            LayerDrawable inactiveLayerDrawable = new LayerDrawable(inactivelayer);
            inactiveLayerDrawable.setId(0, 0);
            inactiveLayerDrawable.setId(1, 1);
            LayerDrawable activeLayerDrawable = new LayerDrawable(activelayer);
            activeLayerDrawable.setId(0, 0);
            activeLayerDrawable.setId(1, 1);
            states.addState(TargetDrawable.STATE_INACTIVE, inactiveLayerDrawable);
            states.addState(TargetDrawable.STATE_ACTIVE, activeLayerDrawable);
            states.addState(TargetDrawable.STATE_FOCUSED, activeLayerDrawable);
            return states;
        }
        
        public boolean isTargetPresent(int resId) {
            return mGlowPadView.getTargetPosition(resId) != -1;
        }
        
        public void updateResources() {
            String storedVal = Settings.System.getString(mContext.getContentResolver(),
                    Settings.System.LOCKSCREEN_TARGETS);
            if (storedVal == null) {
                int resId;
                if (mCameraDisabled && mEnableRingSilenceFallback) {
                    // Fall back to showing ring/silence if camera is disabled...
                    resId = mSilentMode ? R.array.lockscreen_targets_when_silent
                            : R.array.lockscreen_targets_when_soundon;
                } else {
                    resId = R.array.lockscreen_targets_with_camera;
                }
                if (mGlowPadView.getTargetResourceId() != resId) {
                    mGlowPadView.setTargetResources(resId);
                }
                // Update the search icon with drawable from the search .apk
                if (!mSearchDisabled) {
                    Intent intent = SearchManager.getAssistIntent(mContext);
                    if (intent != null) {
                        // XXX Hack. We need to substitute the icon here but haven't formalized
                        // the public API. The "_google" metadata will be going away, so
                        // DON'T USE IT!
                        ComponentName component = intent.getComponent();
                        boolean replaced = mGlowPadView.replaceTargetDrawablesIfPresent(component,
                                ASSIST_ICON_METADATA_NAME + "_google",
                                com.android.internal.R.drawable.ic_action_assist_generic);
        
                        if (!replaced && !mGlowPadView.replaceTargetDrawablesIfPresent(component,
                                    ASSIST_ICON_METADATA_NAME,
                                    com.android.internal.R.drawable.ic_action_assist_generic)) {
                                Slog.w(TAG, "Couldn't grab icon from package " + component);
                        }
                    }
                }
                setEnabled(com.android.internal.R.drawable.ic_lockscreen_camera, !mCameraDisabled);
                setEnabled(com.android.internal.R.drawable.ic_action_assist_generic, !mSearchDisabled);
            } else {
                mStoredTargets = storedVal.split("\\|");
                mIsScreenLarge = isScreenLarge();
                ArrayList<TargetDrawable> storedDraw = new ArrayList<TargetDrawable>();
                final Resources res = getResources();
                final int targetInset = res.getDimensionPixelSize(com.android.internal.R.dimen.lockscreen_target_inset);
                final PackageManager packMan = mContext.getPackageManager();
                final boolean isLandscape = mCreationOrientation == Configuration.ORIENTATION_LANDSCAPE;
                final Drawable blankActiveDrawable = res.getDrawable(R.drawable.ic_lockscreen_target_activated);
                final InsetDrawable activeBack = new InsetDrawable(blankActiveDrawable, 0, 0, 0, 0);
                // Shift targets for landscape lockscreen on phones
                mTargetOffset = isLandscape && !mIsScreenLarge ? 2 : 0;
                if (mTargetOffset == 2) {
                    storedDraw.add(new TargetDrawable(res, null));
                    storedDraw.add(new TargetDrawable(res, null));
                }
                // Add unlock target
                storedDraw.add(new TargetDrawable(res, res.getDrawable(R.drawable.ic_lockscreen_unlock)));
                for (int i = 0; i < 8 - mTargetOffset - 1; i++) {
                    int tmpInset = targetInset;
                    if (i < mStoredTargets.length) {
                        String uri = mStoredTargets[i];
                        if (!uri.equals(GlowPadView.EMPTY_TARGET)) {
                            try {
                                Intent in = Intent.parseUri(uri,0);
                                Drawable front = null;
                                Drawable back = activeBack;
                                boolean frontBlank = false;
                                if (in.hasExtra(GlowPadView.ICON_FILE)) {
                                    String fSource = in.getStringExtra(GlowPadView.ICON_FILE);
                                    if (fSource != null) {
                                        File fPath = new File(fSource);
                                        if (fPath.exists()) {
                                            front = new BitmapDrawable(res, BitmapFactory.decodeFile(fSource));
                                        }
                                    }
                                } else if (in.hasExtra(GlowPadView.ICON_RESOURCE)) {
                                    String rSource = in.getStringExtra(GlowPadView.ICON_RESOURCE);
                                    String rPackage = in.getStringExtra(GlowPadView.ICON_PACKAGE);
                                    if (rSource != null) {
                                        if (rPackage != null) {
                                            try {
                                                Context rContext = mContext.createPackageContext(rPackage, 0);
                                                int id = rContext.getResources().getIdentifier(rSource, "drawable", rPackage);
                                                front = rContext.getResources().getDrawable(id);
                                                id = rContext.getResources().getIdentifier(rSource.replaceAll("_normal", "_activated"),
                                                        "drawable", rPackage);
                                                back = rContext.getResources().getDrawable(id);
                                                tmpInset = 0;
                                                frontBlank = true;
                                            } catch (NameNotFoundException e) {
                                                e.printStackTrace();
                                            } catch (NotFoundException e) {
                                                e.printStackTrace();
                                            }
                                        } else {
                                            front = res.getDrawable(res.getIdentifier(rSource, "drawable", "android"));
                                            back = res.getDrawable(res.getIdentifier(
                                                    rSource.replaceAll("_normal", "_activated"), "drawable", "android"));
                                            tmpInset = 0;
                                            frontBlank = true;
                                        }
                                    }
                                }
                                if (front == null || back == null) {
                                    ActivityInfo aInfo = in.resolveActivityInfo(packMan, PackageManager.GET_ACTIVITIES);
                                    if (aInfo != null) {
                                        front = aInfo.loadIcon(packMan);
                                    } else {
                                        front = res.getDrawable(android.R.drawable.sym_def_app_icon);
                                    }
                                }
                                TargetDrawable nDrawable = new TargetDrawable(res, getLayeredDrawable(back,front, tmpInset, frontBlank));
                                boolean isCamera = in.getComponent().getClassName().equals("com.android.camera.Camera");
                                if (isCamera) {
                                    nDrawable.setEnabled(!mCameraDisabled);
                                } else {
                                    boolean isSearch = in.getComponent().getClassName().equals("SearchActivity");
                                    if (isSearch) {
                                        nDrawable.setEnabled(!mSearchDisabled);
                                    }
                                }
                                storedDraw.add(nDrawable);
                            } catch (Exception e) {
                                storedDraw.add(new TargetDrawable(res, 0));
                            }
                        } else {
                            storedDraw.add(new TargetDrawable(res, 0));
                        }
                    } else {
                        storedDraw.add(new TargetDrawable(res, 0));
                    }
                }
                mGlowPadView.setTargetResources(storedDraw);
            }
        }
        
        public void onGrabbed(View v, int handle) {
        
        }
        
        public void onReleased(View v, int handle) {
        
        }
        
        public void onTrigger(View v, int target) {
            if (mStoredTargets == null) {
                final int resId = mGlowPadView.getResourceIdForTarget(target);
                switch (resId) {
                case com.android.internal.R.drawable.ic_action_assist_generic:
                    Intent assistIntent = SearchManager.getAssistIntent(mContext);
                    if (assistIntent != null) {
                        launchActivity(assistIntent);
                    } else {
                        Log.w(TAG, "Failed to get intent for assist activity");
                    }
                    mCallback.pokeWakelock();
                    break;
        
                case com.android.internal.R.drawable.ic_lockscreen_camera:
                    launchActivity(new Intent(MediaStore.INTENT_ACTION_STILL_IMAGE_CAMERA));
                    mCallback.pokeWakelock();
                    break;
        
                case com.android.internal.R.drawable.ic_lockscreen_silent:
                    toggleRingMode();
                    mCallback.pokeWakelock();
                    break;
        
                case com.android.internal.R.drawable.ic_lockscreen_unlock_phantom:
                case com.android.internal.R.drawable.ic_lockscreen_unlock:
                    mCallback.goToUnlockScreen();
                    break;
                }
            } else {
                final boolean isLand = mCreationOrientation == Configuration.ORIENTATION_LANDSCAPE;
                if ((target == 0 && (mIsScreenLarge || !isLand)) || (target == 2 && !mIsScreenLarge && isLand)) {
                    mCallback.goToUnlockScreen();
                } else {
                    target -= 1 + mTargetOffset;
                    if (target < mStoredTargets.length && mStoredTargets[target] != null) {
                        try {
                            Intent tIntent = Intent.parseUri(mStoredTargets[target], 0);
                            tIntent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                            mContext.startActivity(tIntent);
                            mCallback.goToUnlockScreen();
                            return;
                        } catch (URISyntaxException e) {
                        } catch (ActivityNotFoundException e) {
                        }
                    }
                }
            }
        }
        
        private void launchActivity(Intent intent) {
            intent.setFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK
                    | Intent.FLAG_ACTIVITY_SINGLE_TOP
                    | Intent.FLAG_ACTIVITY_CLEAR_TOP);
            try {
                ActivityManagerNative.getDefault().dismissKeyguardOnNextActivity();
            } catch (RemoteException e) {
                Log.w(TAG, "can't dismiss keyguard on launch");
            }
            try {
                mContext.startActivity(intent);
            } catch (ActivityNotFoundException e) {
                Log.w(TAG, "Activity not found for intent + " + intent.getAction());
            }
        }
        
        public void onGrabbedStateChange(View v, int handle) {
            // Don't poke the wake lock when returning to a state where the handle is
            // not grabbed since that can happen when the system (instead of the user)
            // cancels the grab.
            if (handle != GlowPadView.OnTriggerListener.NO_HANDLE) {
                mCallback.pokeWakelock();
            }
        }
        
        public View getView() {
            return mGlowPadView;
        }
        
        public void reset(boolean animate) {
            mGlowPadView.reset(animate);
        }
        
        public void ping() {
            mGlowPadView.ping();
        }
        
        public void setEnabled(int resourceId, boolean enabled) {
            mGlowPadView.setEnableTarget(resourceId, enabled);
        }
        
        public int getTargetPosition(int resourceId) {
            return mGlowPadView.getTargetPosition(resourceId);
        }
        
        public void cleanUp() {
            mGlowPadView.setOnTriggerListener(null);
        }
        
        public void onFinishFinalAnimation() {
        
        }
    }

    private void requestUnlockScreen() {
        // Delay hiding lock screen long enough for animation to finish
        postDelayed(new Runnable() {
            public void run() {
                mCallback.goToUnlockScreen();
            }
        }, WAIT_FOR_ANIMATION_TIMEOUT);
    }

    private void toggleRingMode() {
        // toggle silent mode
        mSilentMode = !mSilentMode;
        if (mSilentMode) {
            final boolean vibe = (Settings.System.getInt(
                    mContext.getContentResolver(),
                    Settings.System.VIBRATE_IN_SILENT, 1) == 1);

            mAudioManager.setRingerMode(vibe
                    ? AudioManager.RINGER_MODE_VIBRATE
                    : AudioManager.RINGER_MODE_SILENT);
        } else {
            mAudioManager.setRingerMode(AudioManager.RINGER_MODE_NORMAL);
        }
    }

    /**
     * In general, we enable unlocking the insecure key guard with the menu key. However, there are
     * some cases where we wish to disable it, notably when the menu button placement or technology
     * is prone to false positives.
     * 
     * @return true if the menu key should be enabled
     */
    private boolean shouldEnableMenuKey() {
        return (Settings.System.getInt(getContext().getContentResolver(),
                Settings.System.LOCKSCREEN_ENABLE_MENU_KEY, 0) == 1);
    }

    @Override
    public boolean onKeyDown(int keyCode, KeyEvent event) {
        if (keyCode == KeyEvent.KEYCODE_MENU && mEnableMenuKeyInLockScreen) {
            mCallback.goToUnlockScreen();
        }
        return false;
    }

    class Target {
        public static final String ACTION_UNLOCK = "**unlock**";
        public static final String ACTION_SOUND_TOGGLE = "**sound**";
        public static final String ACTION_APP_PHONE = "**phone**";
        public static final String ACTION_APP_CAMERA = "**camera**";
        public static final String ACTION_APP_MMS = "**mms**";
        public static final String ACTION_APP_CUSTOM = "**app**";
        public static final String ACTION_NULL = "**null**";

        String action = ACTION_NULL;
        Drawable icon;
        String customAppIntentUri;
        final Integer index;

        public Target() {
            this.index = null;
        }

        public Target(int index) {
            this.index = index;
        }

        void setDrawable() {
            icon = getDrawable();
        }

        Drawable getDrawable() {
            if(index == null) return null;

            int resId;
            Drawable drawable = null;
            PackageManager pm = getContext().getPackageManager();
            Resources res = getContext().getResources();

            String customIconUri = Settings.System.getString(getContext().getContentResolver(),
                    Settings.System.LOCKSCREEN_CUSTOM_APP_ICONS[index]);
            if(customIconUri != null && !customIconUri.equals("")) {
                if (customIconUri.startsWith("file")) {
                    // it's an icon the user chose from the gallery here
                    File icon = new File(Uri.parse(customIconUri).getPath());
                    if(icon.exists()) {
                        Bitmap b = BitmapFactory.decodeFile(icon.getAbsolutePath());
                        if (b != null) {
                            Drawable ic = new BitmapDrawable(getResources(), b);
                            return resize(ic);
                        } else {
                            Log.e(TAG, "Lockscreen icon URI (" + customIconUri + ") couldn't be decoded. Using stock icon.");
                        }
                    }
                } else {
                    // here they chose another app icon
                    try {
                        return resize(pm.getActivityIcon(Intent.parseUri(customIconUri, 0)));
                    } catch (NameNotFoundException e) {
                        Log.e(TAG, "user chose app's icon that doesn't exist anymore", e);
                    } catch (URISyntaxException e) {
                        Log.e(TAG, "URISyntaxException when setting icon", e);
                    }
                }
            }

            if (action.equals(ACTION_UNLOCK)) {
                resId = R.drawable.ic_lockscreen_unlock;
                drawable = res.getDrawable(resId);
            } else if (action.equals(ACTION_APP_PHONE)) {
                resId = R.drawable.ic_lockscreen_phone;
                drawable = res.getDrawable(resId);
            } else if (action.equals(ACTION_APP_CAMERA)) {
                resId = R.drawable.ic_lockscreen_camera;
                drawable = res.getDrawable(resId);
            } else if (action.equals(ACTION_APP_MMS)) {
                    resId = R.drawable.ic_lockscreen_sms;
                    drawable = res.getDrawable(resId);
            } else if (action.equals(ACTION_SOUND_TOGGLE)) {
                resId = mSilentMode ? R.drawable.ic_lockscreen_silent
                        : R.drawable.ic_lockscreen_soundon;
                drawable = res.getDrawable(resId);
            } else if (action.equals(ACTION_NULL)) {
                drawable = null;
            } else if (action.equals(ACTION_APP_CUSTOM)) {
                try {
                    Intent intent = Intent.parseUri(customAppIntentUri, 0);
                    drawable = resize(pm.getActivityIcon(intent));
                } catch (PackageManager.NameNotFoundException e) {
                    Log.e(TAG, "NameNotFoundException: [" + customAppIntentUri + "]");
                } catch (URISyntaxException e) {
                    Log.e(TAG, "URISyntaxException: [" + customAppIntentUri + "]");
                }
            }
            return drawable;
        }

        void doAction() {
            if (action.equals(ACTION_UNLOCK)) {
                mCallback.goToUnlockScreen();
            } else if (action.equals(ACTION_APP_PHONE)) {
                Intent phoneIntent = new Intent(Intent.ACTION_MAIN);
                phoneIntent.setClassName("com.android.contacts",
                        "com.android.contacts.activities.DialtactsActivity");
                phoneIntent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                mContext.startActivity(phoneIntent);
                mCallback.goToUnlockScreen();
            } else if (action.equals(ACTION_APP_MMS)) {
                Intent intent = new Intent(Intent.ACTION_MAIN);
                intent.addCategory(Intent.CATEGORY_LAUNCHER);
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK
                        | Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED);
                intent.setClassName("com.android.mms", "com.android.mms.ui.ConversationList");
                mContext.startActivity(intent);
                mCallback.goToUnlockScreen();
            } else if (action.equals(ACTION_APP_CAMERA)) {
                Intent intent = new Intent(MediaStore.INTENT_ACTION_STILL_IMAGE_CAMERA);
                intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                mContext.startActivity(intent);
                mCallback.goToUnlockScreen();
            } else if (action.equals(ACTION_SOUND_TOGGLE)) {
                toggleRingMode();
                mUnlockWidgetMethods.updateResources();

                String message = mSilentMode ?
                        getContext().getString(R.string.global_action_silent_mode_on_status)
                        : getContext().getString(R.string.global_action_silent_mode_off_status);

                final int toastIcon = mSilentMode ? R.drawable.ic_lock_ringer_off
                        : R.drawable.ic_lock_ringer_on;

                final int toastColor = mSilentMode ?
                        getContext().getResources().getColor(R.color.keyguard_text_color_soundoff)
                        : getContext().getResources().getColor(R.color.keyguard_text_color_soundon);
                toastMessage(mCarrier, message, toastColor, toastIcon);

                mCallback.pokeWakelock();
            } else if (action.equals(ACTION_APP_CUSTOM) && customAppIntentUri != null) {
                try {
                    Intent intent = Intent.parseUri(customAppIntentUri, 0);
                    intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                    mContext.startActivity(intent);
                    mCallback.goToUnlockScreen();
                } catch (URISyntaxException e) {
                    Log.e(TAG, "URISyntaxException: [" + customAppIntentUri + "]");
                }
            }
        }
    }

    class TargetController {
        ArrayList<Target> targets = new ArrayList<Target>();
        int unlockTarget = -1;
        boolean landscape = false;

        public TargetController() {
            setupTargets();
        }

        public void setLandscape(boolean isLandscape) {
            this.landscape = isLandscape;

        }

        public void setupTargets() {
            targets.clear();

            int numTargets = mLockscreenTargets;

            int numPadding = 0;
            if(numTargets == LAYOUT_TRI) numPadding = 1;
                else if(numTargets == LAYOUT_QUAD) numPadding = 2;
                else if(numTargets == LAYOUT_HEPTA) numPadding = 3;

            for (int i = 0; i < numTargets; i++) {
                String settingUri = Settings.System.getString(mContext.getContentResolver(),
                        Settings.System.LOCKSCREEN_CUSTOM_APP_ACTIVITIES[i]);
                Target t = new Target(i);
                if (settingUri == null) {
                    if (i == 0) {
                        t.action = Target.ACTION_UNLOCK;
                    } else if (numTargets == 2 && i == 1) {
                        t.action = Target.ACTION_APP_CAMERA;
                    } else if ((numTargets / 2) == (i + 1)) {
                        t.action = Target.ACTION_APP_CAMERA;
                    }
                } else {
                    if (settingUri.equals(Target.ACTION_UNLOCK)) {
                        t.action = Target.ACTION_UNLOCK;
                        unlockTarget = i;
                    } else if (settingUri.equals(Target.ACTION_APP_CAMERA)) {
                        t.action = Target.ACTION_APP_CAMERA;
                    } else if (settingUri.equals(Target.ACTION_APP_PHONE)) {
                        t.action = Target.ACTION_APP_PHONE;
                    } else if (settingUri.equals(Target.ACTION_SOUND_TOGGLE)) {
                        t.action = Target.ACTION_SOUND_TOGGLE;
                    } else if (settingUri.equals(Target.ACTION_APP_MMS)) {
                        t.action = Target.ACTION_APP_MMS;
                    } else {
                        t.action = Target.ACTION_APP_CUSTOM;
                        t.customAppIntentUri = settingUri;
                    }
                }
                t.setDrawable();
                targets.add(t);
            }

            for (int i = 0; i < numPadding; i++) {
                targets.add(new Target());
            }

            if (unlockTarget == -1)
                if (targets.size() > 1)
                    targets.get(0).action = Target.ACTION_UNLOCK;
                else {
                    Target t = new Target(0);
                    t.action = Target.ACTION_UNLOCK;
                    targets.add(0, t);
                }
        }

        public Drawable[] getDrawables() {
            int size = targets.size();
            Drawable[] d = new Drawable[size];
            for (int i = 0; i < targets.size(); i++)
                d[i] = targets.get(i).getDrawable();

            return d;
        }

        public Target getTarget(int target) {
            return targets.get(target);
        }
    }

    TargetController targetController;

    /**
     * @param context Used to setup the view.
     * @param configuration The current configuration. Used to use when selecting layout, etc.
     * @param lockPatternUtils Used to know the state of the lock pattern settings.
     * @param updateMonitor Used to register for updates on various keyguard related state, and
     *            query the initial state at setup.
     * @param callback Used to communicate back to the host keyguard view.
     */
    LockScreen(Context context, Configuration configuration, LockPatternUtils lockPatternUtils,
            KeyguardUpdateMonitor updateMonitor,
            KeyguardScreenCallback callback) {
        super(context);
        mLockPatternUtils = lockPatternUtils;
        mUpdateMonitor = updateMonitor;
        mCallback = callback;
        mEnableMenuKeyInLockScreen = shouldEnableMenuKey();
        mCreationOrientation = configuration.orientation;

        mSettingsObserver = new SettingsObserver(new Handler());
        mSettingsObserver.observe();

        targetController = new TargetController();

        if (LockPatternKeyguardView.DEBUG_CONFIGURATION) {
            Log.v(TAG, "***** CREATING LOCK SCREEN", new RuntimeException());
            Log.v(TAG, "Cur orient=" + mCreationOrientation
                    + " res orient=" + context.getResources().getConfiguration().orientation);
        }

        final LayoutInflater inflater = LayoutInflater.from(context);
        if (DBG)
            Log.v(TAG, "Creation orientation = " + mCreationOrientation);

        boolean landscape = mCreationOrientation == Configuration.ORIENTATION_LANDSCAPE;

        switch (mLockscreenTargets) {
            default:
            case LAYOUT_STOCK:
            case LAYOUT_TRI:
            case LAYOUT_QUAD:
            case LAYOUT_HEPTA:
                if (landscape)
                    inflater.inflate(R.layout.keyguard_screen_tab_unlock_land, this,
                            true);
                else
                    inflater.inflate(R.layout.keyguard_screen_tab_unlock, this,
                            true);
                break;
            case LAYOUT_HEXA:
            case LAYOUT_SEPTA:
            case LAYOUT_OCTO:
                if (landscape)
                    inflater.inflate(R.layout.keyguard_screen_tab_octounlock_land, this,
                            true);
                else
                    inflater.inflate(R.layout.keyguard_screen_tab_octounlock, this,
                            true);
                break;
            case LAYOUT_AOSP:
            	if (landscape)
                    inflater.inflate(R.layout.keyguard_screen_slidingtab_unlock_land, this,
                            true);
                else 
                    inflater.inflate(R.layout.keyguard_screen_slidingtab_unlock, this,
                            true);
                break;
            case LAYOUT_HONEY:
            	if (landscape)
                    inflater.inflate(R.layout.keyguard_screen_honeycomb_unlock_land, this,
                            true);
                else 
                    inflater.inflate(R.layout.keyguard_screen_honeycomb_unlock, this,
                            true);
                break;
                
        }

        setBackground(mContext, (ViewGroup) findViewById(R.id.root));

        mStatusViewManager = new KeyguardStatusViewManager(this, mUpdateMonitor, mLockPatternUtils,
                mCallback, false);

        setFocusable(true);
        setFocusableInTouchMode(true);
        setDescendantFocusability(ViewGroup.FOCUS_BLOCK_DESCENDANTS);

        mAudioManager = (AudioManager) mContext.getSystemService(Context.AUDIO_SERVICE);
        mSilentMode = isSilentMode();

        mCarrier = (TextView) findViewById(R.id.carrier);
        mDigitalClock = (DigitalClock) findViewById(R.id.time);

        mUnlockWidget = findViewById(R.id.unlock_widget);
        mUnlockWidgetMethods = createUnlockMethods(mUnlockWidget);

        if (DBG) Log.v(TAG, "*** LockScreen accel is "
                + (mUnlockWidget.isHardwareAccelerated() ? "on":"off"));
    }

    private UnlockWidgetCommonMethods createUnlockMethods(View unlockWidget) {
        if (unlockWidget instanceof SlidingTab) {
            SlidingTab slidingTabView = (SlidingTab) unlockWidget;
            slidingTabView.setHoldAfterTrigger(true, false);
            slidingTabView.setLeftHintText(R.string.lockscreen_unlock_label);
            slidingTabView.setLeftTabResources(
                    R.drawable.ic_jog_dial_unlock,
                    R.drawable.jog_tab_target_green,
                    R.drawable.jog_tab_bar_left_unlock,
                    R.drawable.jog_tab_left_unlock);
            SlidingTabMethods slidingTabMethods = new SlidingTabMethods(slidingTabView);
            slidingTabView.setOnTriggerListener(slidingTabMethods);
            mUnlockWidgetMethods = slidingTabMethods;
            mUnlockWidget2 = findViewById(R.id.unlock_widget2);
            if(mUnlockWidget2 == null) {
                return slidingTabMethods;
            } else{
                SlidingTab slidingTabView2 = (SlidingTab) mUnlockWidget2;
                slidingTabView2.setHoldAfterTrigger(true, false);
                slidingTabView2.setLeftHintText(R.string.lockscreen_phone_label);
                slidingTabView2.setLeftTabResources(
                        R.drawable.ic_jog_dial_answer,
                        R.drawable.jog_tab_target_green,
                        R.drawable.jog_tab_bar_left_generic,
                        R.drawable.jog_tab_left_generic);
                slidingTabView2.setRightHintText(R.string.lockscreen_custom_label);
                slidingTabView2.setRightTabResources(
                        R.drawable.ic_jog_dial_custom,
                        R.drawable.jog_tab_target_green,
                        R.drawable.jog_tab_bar_right_generic,
                        R.drawable.jog_tab_right_generic);
                SlidingTabMethods2 slidingTabMethods2 = new SlidingTabMethods2(slidingTabView2);
                slidingTabView2.setOnTriggerListener(slidingTabMethods2);
                if (mLockscreen4Tab)
                    slidingTabView2.setVisibility(View.VISIBLE);
                else	
                    slidingTabView2.setVisibility(View.GONE);
                return slidingTabMethods2;
            }
        } else if (mUnlockWidget instanceof WaveView) {
            WaveView waveView = (WaveView) mUnlockWidget;
            WaveViewMethods waveViewMethods = new WaveViewMethods(waveView);
            waveView.setOnTriggerListener(waveViewMethods);
            return waveViewMethods;
        } else if (unlockWidget instanceof GlowPadView) {
            GlowPadView glowPadView = (GlowPadView) unlockWidget;
            GlowPadViewMethods glowPadViewMethods = new GlowPadViewMethods(glowPadView);
            glowPadView.setOnTriggerListener(glowPadViewMethods);
            return glowPadViewMethods;
        } else {
            throw new IllegalStateException("Unrecognized unlock widget: " + unlockWidget);
        }
    }

    private void updateTargets() {
        boolean disabledByAdmin = mLockPatternUtils.getDevicePolicyManager()
                .getCameraDisabled(null);
        boolean disabledBySimState = mUpdateMonitor.isSimLocked();
        boolean cameraTargetPresent = (mUnlockWidgetMethods instanceof GlowPadViewMethods)
                ? ((GlowPadViewMethods) mUnlockWidgetMethods)
                        .isTargetPresent(com.android.internal.R.drawable.ic_lockscreen_camera)
                        : false;
        boolean searchTargetPresent = (mUnlockWidgetMethods instanceof GlowPadViewMethods)
                ? ((GlowPadViewMethods) mUnlockWidgetMethods)
                        .isTargetPresent(com.android.internal.R.drawable.ic_action_assist_generic)
                        : false;

        if (disabledByAdmin) {
            Log.v(TAG, "Camera disabled by Device Policy");
        } else if (disabledBySimState) {
            Log.v(TAG, "Camera disabled by Sim State");
        }
        boolean searchActionAvailable = SearchManager.getAssistIntent(mContext) != null;
        mCameraDisabled = disabledByAdmin || disabledBySimState || !cameraTargetPresent;
        mSearchDisabled = disabledBySimState || !searchActionAvailable || !searchTargetPresent;
        mUnlockWidgetMethods.updateResources();
        // Update the settings everytime we draw lockscreen
        updateSettings();

        if (DBG)
            Log.v(TAG, "*** LockScreen accel is "
                    + (mUnlockWidget.isHardwareAccelerated() ? "on" : "off"));
    }

    static void setBackground(Context context, ViewGroup layout) {
        String lockBack = Settings.System.getString(context.getContentResolver(), Settings.System.LOCKSCREEN_BACKGROUND);
        if (lockBack != null) {
            if (!lockBack.isEmpty()) {
                try {
                    layout.setBackgroundColor(Integer.parseInt(lockBack));
                } catch(NumberFormatException e) {
                    e.printStackTrace();
                }
            } else {
                try {
                    ViewParent parent =  layout.getParent();
                    if (parent != null) {
                        //change parent to show background correctly on scale
                        RelativeLayout rlout = new RelativeLayout(context);
                        ((ViewGroup) parent).removeView(layout);
                        layout.setLayoutParams(new LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));
                        ((ViewGroup) parent).addView(rlout); // change parent to new layout
                        rlout.addView(layout);
                        // create framelayout and add imageview to set background
                        FrameLayout flayout = new FrameLayout(context);
                        flayout.setLayoutParams(new LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));
                        ImageView mLockScreenWallpaperImage = new ImageView(flayout.getContext());
                        mLockScreenWallpaperImage.setScaleType(ScaleType.CENTER_CROP);
                        flayout.addView(mLockScreenWallpaperImage, -1, -1);
                        Context settingsContext = context.createPackageContext("com.android.settings", 0);
                        String wallpaperFile = settingsContext.getFilesDir() + "/lockwallpaper";
                        Bitmap background = BitmapFactory.decodeFile(wallpaperFile);
                        Drawable d = new BitmapDrawable(context.getResources(), background);
                        mLockScreenWallpaperImage.setImageDrawable(d);
                        // add background to lock screen.
                        rlout.addView(flayout,0);
                    }
                } catch (NameNotFoundException e) {
                }
            }
        }
    }

    private boolean isSilentMode() {
        return mAudioManager.getRingerMode() != AudioManager.RINGER_MODE_NORMAL;
    }

    /**
     * Displays a message in a text view and then restores the previous text.
     * 
     * @param textView The text view.
     * @param text The text.
     * @param color The color to apply to the text, or 0 if the existing color should be used.
     * @param iconResourceId The left hand icon.
     */
    private void toastMessage(final TextView textView, final String text,
            final int color, final int iconResourceId) {
        if (mPendingR1 != null) {
            textView.removeCallbacks(mPendingR1);
            mPendingR1 = null;
        }
        if (mPendingR2 != null) {
            mPendingR2.run(); // fire immediately, restoring non-toasted appearance
            textView.removeCallbacks(mPendingR2);
            mPendingR2 = null;
        }
        final String oldText = textView.getText().toString();
        final ColorStateList oldColors = textView.getTextColors();

        mPendingR1 = new Runnable() {
            public void run() {
                textView.setText(text);
                if (color != 0) {
                    textView.setTextColor(color);
                }
                textView.setCompoundDrawablesWithIntrinsicBounds(0, iconResourceId, 0, 0);
            }
        };

        textView.postDelayed(mPendingR1, 0);
        mPendingR2 = new Runnable() {
            public void run() {
                textView.setText(oldText);
                textView.setTextColor(oldColors);
                textView.setCompoundDrawablesWithIntrinsicBounds(0, 0, 0, 0);
            }
        };
        textView.postDelayed(mPendingR2, 3500);
    }

    private Runnable mPendingR1;
    private Runnable mPendingR2;
    
    void updateConfiguration() {
        Configuration newConfig = getResources().getConfiguration();
        if (newConfig.orientation != mCreationOrientation) {
            mCallback.recreateMe(newConfig);
        }
    }

    @Override
    protected void onAttachedToWindow() {
        super.onAttachedToWindow();
        if (LockPatternKeyguardView.DEBUG_CONFIGURATION) {
            Log.v(TAG, "***** LOCK ATTACHED TO WINDOW");
            Log.v(TAG, "Cur orient=" + mCreationOrientation
                    + ", new config=" + getResources().getConfiguration());
        }
        updateConfiguration();
        updateSettings();
    }

    /** {@inheritDoc} */
    @Override
    protected void onConfigurationChanged(Configuration newConfig) {
        super.onConfigurationChanged(newConfig);
        if (LockPatternKeyguardView.DEBUG_CONFIGURATION) {
            Log.w(TAG, "***** LOCK CONFIG CHANGING", new RuntimeException());
            Log.v(TAG, "Cur orient=" + mCreationOrientation
                    + ", new config=" + newConfig);
        }
        updateConfiguration();
    }

    /** {@inheritDoc} */
    public boolean needsInput() {
        return false;
    }

    /** {@inheritDoc} */
    public void onPause() {
        mUpdateMonitor.removeCallback(mInfoCallback);
        mUpdateMonitor.removeCallback(mSimStateCallback);
        mStatusViewManager.onPause();
        mUnlockWidgetMethods.reset(false);
    }

    private final Runnable mOnResumePing = new Runnable() {
        public void run() {
            mUnlockWidgetMethods.ping();
        }
    };

    /** {@inheritDoc} */
    public void onResume() {
        // We don't want to show the camera target if SIM state prevents us from
        // launching the camera. So watch for SIM changes...
        mUpdateMonitor.registerSimStateCallback(mSimStateCallback);
        mUpdateMonitor.registerInfoCallback(mInfoCallback);

        mStatusViewManager.onResume();
        postDelayed(mOnResumePing, ON_RESUME_PING_DELAY);
        // update the settings when we resume
        if (DEBUG) Log.d(TAG, "We are resuming and want to update settings");
        updateSettings();
    }

    /** {@inheritDoc} */
    public void cleanUp() {
        mUpdateMonitor.removeCallback(mInfoCallback); // this must be first
        mUpdateMonitor.removeCallback(mSimStateCallback);
        mUnlockWidgetMethods.cleanUp();
        mLockPatternUtils = null;
        mUpdateMonitor = null;
        mCallback = null;
    }

    /** {@inheritDoc} */
    public void onRingerModeChanged(int state) {
        boolean silent = AudioManager.RINGER_MODE_NORMAL != state;
        if (silent != mSilentMode) {
            mSilentMode = silent;
            mUnlockWidgetMethods.updateResources();
        }
    }

    public void onPhoneStateChanged(String newState) {
    }

    class SettingsObserver extends ContentObserver {
        SettingsObserver(Handler handler) {
            super(handler);
        }

        void observe() {
            ContentResolver resolver = mContext.getContentResolver();
            resolver.registerContentObserver(
                    Settings.System.getUriFor(Settings.System.LOCKSCREEN_LAYOUT), false,
                    this);
            resolver.registerContentObserver(
                    Settings.System.getUriFor(Settings.System.LOCKSCREEN_CUSTOM_TEXT_COLOR), false,
                    this);
            updateSettings();
        }

        @Override
        public void onChange(boolean selfChange) {
            updateSettings();
        }
    }

    private Drawable resize(Drawable image) {
        int size = 40;
        int px = (int) TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, size, getResources().getDisplayMetrics());

        Bitmap d = ((BitmapDrawable) image).getBitmap();
        Bitmap bitmapOrig = Bitmap.createScaledBitmap(d, px, px, false);
        return new BitmapDrawable(getContext().getResources(), bitmapOrig);
    }

    private void updateSettings() {
    	if (DEBUG) Log.d(TAG, "Settings for lockscreen have changed lets update");
        ContentResolver resolver = mContext.getContentResolver();

        mLockscreenTargets = Settings.System.getInt(resolver,
                Settings.System.LOCKSCREEN_LAYOUT, LAYOUT_STOCK);
        
        // digital clock first (see @link com.android.internal.widget.DigitalClock.updateTime())
        try {
            mDigitalClock.updateTime();
        } catch (NullPointerException npe) {
            if (DEBUG) Log.d(TAG, "date update time failed: NullPointerException");
        }

        // then the rest (see @link com.android.internal.policy.impl.KeyguardStatusViewManager.updateColors())
        try {
            mStatusViewManager.updateColors(); 
        } catch (NullPointerException npe) {
            if (DEBUG) Log.d(TAG, "KeyguardStatusViewManager.updateColors() failed: NullPointerException");
        }
    }

	private void runActivity(String uri) {
		try {
			Intent i = Intent.parseUri(uri, 0);
			i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK
					| Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED);
			mContext.startActivity(i);
			mCallback.goToUnlockScreen();
		} catch (URISyntaxException e) {
		} catch (ActivityNotFoundException e) {
		}
	}
}

