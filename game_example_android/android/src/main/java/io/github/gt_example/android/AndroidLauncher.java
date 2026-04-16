package io.github.gt_example.android;

import android.os.Bundle;
import android.view.KeyEvent;
import android.view.View;
import android.view.WindowManager;

import com.badlogic.gdx.backends.android.AndroidApplication;
import com.badlogic.gdx.backends.android.AndroidApplicationConfiguration;
import com.project.AndroidHardwareInputBridge;

import io.github.gt_example.Main;

/** Launches the Android application. */
public class AndroidLauncher extends AndroidApplication {
    private View gameView;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_ALT_FOCUSABLE_IM);
        getWindow().setSoftInputMode(
            WindowManager.LayoutParams.SOFT_INPUT_STATE_ALWAYS_HIDDEN
                | WindowManager.LayoutParams.SOFT_INPUT_ADJUST_NOTHING
        );
        AndroidApplicationConfiguration configuration = new AndroidApplicationConfiguration();
        configuration.useImmersiveMode = true;
        gameView = initializeForView(new Main(), configuration);
        gameView.setFocusable(true);
        gameView.setFocusableInTouchMode(true);
        setContentView(gameView);
        getWindow().takeKeyEvents(true);
        gameView.requestFocus();
    }

    @Override
    public boolean onKeyDown(int keyCode, KeyEvent event) {
        if (AndroidHardwareInputBridge.isCaptureEnabled() && handleGameplayKeyDown(keyCode, event)) {
            return true;
        }
        return super.onKeyDown(keyCode, event);
    }

    @Override
    public boolean onKeyUp(int keyCode, KeyEvent event) {
        if (AndroidHardwareInputBridge.isCaptureEnabled() && handleGameplayKeyUp(keyCode)) {
            return true;
        }
        return super.onKeyUp(keyCode, event);
    }

    @Override
    public void onWindowFocusChanged(boolean hasFocus) {
        super.onWindowFocusChanged(hasFocus);
        if (hasFocus && gameView != null) {
            gameView.requestFocus();
        }
    }

    private boolean handleGameplayKeyDown(int keyCode, KeyEvent event) {
        switch (keyCode) {
            case KeyEvent.KEYCODE_DPAD_LEFT:
            case KeyEvent.KEYCODE_A:
                AndroidHardwareInputBridge.pressLeft();
                return true;
            case KeyEvent.KEYCODE_DPAD_RIGHT:
            case KeyEvent.KEYCODE_D:
                AndroidHardwareInputBridge.pressRight();
                return true;
            case KeyEvent.KEYCODE_DPAD_UP:
            case KeyEvent.KEYCODE_W:
                AndroidHardwareInputBridge.pressUp();
                if (event.getRepeatCount() == 0) {
                    AndroidHardwareInputBridge.pressJump();
                }
                return true;
            case KeyEvent.KEYCODE_DPAD_DOWN:
            case KeyEvent.KEYCODE_S:
                AndroidHardwareInputBridge.pressDown();
                return true;
            case KeyEvent.KEYCODE_SPACE:
                if (event.getRepeatCount() == 0) {
                    AndroidHardwareInputBridge.pressJump();
                }
                return true;
            case KeyEvent.KEYCODE_R:
                if (event.getRepeatCount() == 0) {
                    AndroidHardwareInputBridge.pressReset();
                }
                return true;
            default:
                return false;
        }
    }

    private boolean handleGameplayKeyUp(int keyCode) {
        switch (keyCode) {
            case KeyEvent.KEYCODE_DPAD_LEFT:
            case KeyEvent.KEYCODE_A:
                AndroidHardwareInputBridge.releaseLeft();
                return true;
            case KeyEvent.KEYCODE_DPAD_RIGHT:
            case KeyEvent.KEYCODE_D:
                AndroidHardwareInputBridge.releaseRight();
                return true;
            case KeyEvent.KEYCODE_DPAD_UP:
            case KeyEvent.KEYCODE_W:
                AndroidHardwareInputBridge.releaseUp();
                AndroidHardwareInputBridge.releaseJump();
                return true;
            case KeyEvent.KEYCODE_DPAD_DOWN:
            case KeyEvent.KEYCODE_S:
                AndroidHardwareInputBridge.releaseDown();
                return true;
            case KeyEvent.KEYCODE_SPACE:
                AndroidHardwareInputBridge.releaseJump();
                return true;
            default:
                return false;
        }
    }
}
