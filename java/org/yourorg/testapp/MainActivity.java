package org.yourorg.testapp;

import android.app.Activity;
import android.os.Bundle;
import android.widget.TextView;
import androidx.activity.EdgeToEdge;

public class MainActivity extends Activity {
	static {
		System.loadLibrary("testapp");
	}

	public native String getMessage();

	@Override
	protected void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);
		setContentView(R.layout.activity_main);

		TextView text = (TextView)findViewById(R.id.my_text);
		text.setText(getMessage());
	}
}
