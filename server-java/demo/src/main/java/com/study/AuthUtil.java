package com.study;

import jakarta.ws.rs.core.Response;
import com.study.dto.ErrorResponse;

/**
 * Utility class for authentication and authorization.
 * Provides methods to parse and validate user tokens.
 */
public class AuthUtil {
    
    /**
     * Parses the userId from the Authorization header token.
     * Expected token format: "Bearer jwt_fake_{userId}" or just "{userId}" for dev.
     * 
     * @param token The Authorization header value
     * @return The userId extracted from the token
     * @throws IllegalArgumentException if token is invalid or missing
     */
    public static long getUserIdFromToken(String token) throws IllegalArgumentException {
        if (token == null || token.trim().isEmpty()) {
            throw new IllegalArgumentException("Authorization token is required");
        }
        
        String tokenValue = token.trim();
        
        // Remove "Bearer " prefix if present
        if (tokenValue.toLowerCase().startsWith("bearer ")) {
            tokenValue = tokenValue.substring(7).trim();
        }
        
        // Parse jwt_fake_{userId} format (from AuthController.login)
        if (tokenValue.startsWith("jwt_fake_")) {
            try {
                String userIdStr = tokenValue.substring(9); // Remove "jwt_fake_" prefix
                return Long.parseLong(userIdStr);
            } catch (NumberFormatException e) {
                throw new IllegalArgumentException("Invalid token format");
            }
        }
        
        // Fallback: try to parse as numeric userId directly (for dev/testing)
        try {
            return Long.parseLong(tokenValue);
        } catch (NumberFormatException e) {
            throw new IllegalArgumentException("Invalid token format");
        }
    }
    
    /**
     * Creates a 401 Unauthorized response with an error message.
     * 
     * @param message The error message
     * @return A Response object with 401 status
     */
    public static Response createUnauthorizedResponse(String message) {
        return Response.status(401)
                .entity(new ErrorResponse(false, message))
                .build();
    }
}
