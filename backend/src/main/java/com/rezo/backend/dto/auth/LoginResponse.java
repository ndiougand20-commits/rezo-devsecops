package com.rezo.backend.dto.auth;

public class LoginResponse {

    private final String token;
    private final String refreshToken;

    public LoginResponse(String token) {
        this(token, null);
    }

    public LoginResponse(String token, String refreshToken) {
        this.token = token;
        this.refreshToken = refreshToken;
    }

    public String getToken() {
        return token;
    }

    public String getRefreshToken() {
        return refreshToken;
    }
}
