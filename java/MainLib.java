package org.yourorg.testapp;

public final class MainLib {
	static {
		System.loadLibrary("testapp");
	}

	public static native String getMessage();
}
