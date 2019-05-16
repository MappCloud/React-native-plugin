package com.reactlibrary;

import android.content.Context;
import android.content.pm.PackageManager;
import android.os.AsyncTask;
import android.support.annotation.NonNull;
import android.support.annotation.Nullable;

/**
 * Created by Aleksandar Marinkovic on 2019-05-15.
 * Copyright (c) 2019 MAPP.
 */
public class ReqiestPermissionsTask {

    static class RequestPermissionsTask extends AsyncTask<String, Void, Boolean> {

        private  Context context;
        private Callback callback;

        /**
         * Callback when with the result.
         */
        public interface Callback {
            void onResult(boolean enabled);
        }

        /**
         * Creates a request permissions task.
         * @param context The application context.
         * @param callback The callback.
         */
        RequestPermissionsTask(@NonNull Context context, @Nullable Callback callback) {
            this.context = context;
            this.callback = callback;
        }

        @Override
        protected Boolean doInBackground(String... strings) {
            int[] result = ActivityListener.requestPermissions(context, strings);
            for (int element : result) {
                if (element == PackageManager.PERMISSION_GRANTED) {
                    return true;
                }
            }

            return false;
        }

        @Override
        protected void onPostExecute(Boolean result) {
            if (callback != null) {
                callback.onResult(result);
            }
        }
    }

}
