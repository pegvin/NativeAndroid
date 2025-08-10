package org.yourorg.testapp;

import android.app.Activity;
import android.os.Bundle;
import android.widget.TextView;
import android.widget.Toast;

public class MainActivity extends Activity {
	@Override
	protected void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);
		setContentView(R.layout.activity_main);

		TextView text = (TextView)findViewById(R.id.my_text);
		String msg = MainLib.getMessage();
		text.setText(msg);
		ShowToast(msg);
	}

	@Override
	protected void onResume() {
		super.onResume();
		TextView text = (TextView)findViewById(R.id.my_text);
		text.setText(MainLib.getMessage());
	}

	void ShowToast(String s) {
		Toast toast = Toast.makeText(MainActivity.this, s, Toast.LENGTH_LONG);
		toast.show();
	}
}
