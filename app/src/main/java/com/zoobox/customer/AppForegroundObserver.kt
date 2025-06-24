package com.zoobox.customer

import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import android.util.Log

class AppForegroundObserver : DefaultLifecycleObserver {

    companion object {
        var isAppInForeground = false
            private set
    }

    override fun onStart(owner: LifecycleOwner) {
        super.onStart(owner)
        isAppInForeground = true
        Log.d("AppForegroundObserver", "App moved to foreground - volume buttons can now silence notifications")
    }

    override fun onStop(owner: LifecycleOwner) {
        super.onStop(owner)
        isAppInForeground = false
        Log.d("AppForegroundObserver", "App moved to background - volume buttons work normally")
    }
}