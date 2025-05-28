//
//  Components.swift
//  MatrixSiv
//
//  Created by Rachel Castor on 4/25/25.
//

import Foundation
import SwiftUI

extension View {
    func sivButtonStyle(size: ButtonSize = .medium, style: ButtonStyle = .primary) -> some View {
        self
            .sivTypography(.labelSmall)
            .padding(.horizontal, size.horizontalPadding)
            .padding(.vertical, size.verticalPadding)
            .foregroundStyle(style.foregroundColor)
            .background(style.backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: size.cornerRadius))
    }
    func sivTypography(_ typography: Typography) -> some View {
        self
            .font(.system(size: typography.size))
            .fontWeight(typography.weight)
    }
    
    func squareSize(_ size: CGFloat) -> some View {
        self.frame(width: size, height: size)
    }
    
    func sivAvatar(_ size: CGFloat = 44) -> some View {
        self.squareSize(size)
            .background(.sivGray4)
            .foregroundStyle(.sivGray3)
            .clipShape(Circle())
    }
}

extension Image {
    func sivAvatarImage(_ size: CGFloat = 44) -> some View {
        self.resizable()
            .sivAvatar(size)
    }
}
enum ButtonSize {
    case small, medium, large
    
    var horizontalPadding: CGFloat {
        12
    }
    var verticalPadding: CGFloat {
        8
    }
    
    var cornerRadius: CGFloat {
        8
    }
}

enum ButtonStyle {
    case primary, secondary, tertiary
    
    var foregroundColor: Color {
        switch self {
        case .primary:
            Color(.systemBackground)
        case .secondary:
                .sivPrimary
        case .tertiary:
                .sivPrimary
        }
    }
    
    var backgroundColor: Color {
        switch self {
        case .primary:
                .sivPrimary
        case .secondary:
                .sivPrimarySubtle
        case .tertiary:
                .clear
        }
    }
}

enum Typography {
    case labelSmall
    case labelMedium, labelLarge
    case titleMedium, titleSmall
    case titleLarge
    case bodyMedium
    case bodyLarge
    
    
    var size: CGFloat {
        switch self {
        case .labelSmall:
            12
        case .labelMedium, .titleSmall:
            14
        case .titleMedium, .bodyLarge, .labelLarge:
            16
        case .bodyMedium:
            14
        case .titleLarge:
            22
        }
        
    }
    
    var weight: Font.Weight {
        switch self {
        case .labelSmall, .bodyMedium, .bodyLarge:
                .regular
        case .titleMedium, .labelMedium, .labelLarge, .titleSmall:
                .semibold
        case .titleLarge:
                .heavy
        }
    }
}
